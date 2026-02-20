defmodule Angle.Recommendations.Jobs.ComputeItemSimilarities do
  @moduledoc """
  Background job to pre-compute item similarity scores and populate the ETS cache.

  Computes similarities between items using SimilarityScorer based on:
  - Category match (50% weight)
  - Price range overlap (30% weight)
  - Collaborative filtering from shared users (20% weight)

  ## Processing Strategy
  - Processes 50 items per batch
  - 500ms sleep between batches to avoid overloading the system
  - Computes top 20 similar items per item
  - Stores results in both database (ItemSimilarity) and cache (Cache.put_similar_items)
  - Supports both full computation (all active items) and single item computation

  ## Oban Configuration
  - Queue: :recommendations_slow (for long-running batch operations)
  - Max attempts: 3
  - Uniqueness: 1 hour period (prevents duplicate runs)
  """

  use Oban.Worker,
    queue: :recommendations_slow,
    max_attempts: 3,
    unique: [period: 3600]

  alias Angle.Recommendations.Scoring.SimilarityScorer
  alias Angle.Recommendations.{Cache, ItemSimilarity}
  alias Angle.Inventory.Item
  require Ash.Query
  require Logger

  @batch_size 50
  @batch_sleep_ms 500
  @top_n_similar 20
  @log_prefix "[ComputeItemSimilarities]"

  @doc """
  Performs the item similarity computation job.

  ## Args
  - `item_id` (optional) - If provided, computes similarities only for this item.
                          If omitted, computes for all active items.

  ## Return values
  - `:ok` on successful completion
  - `{:error, reason}` if critical failure occurs
  """
  @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"item_id" => item_id}}) do
    Logger.info("#{@log_prefix} Computing similarities for item #{item_id}")

    case compute_single_item(item_id) do
      :ok ->
        Logger.info("#{@log_prefix} Complete for item #{item_id}")
        :ok

      {:error, reason} ->
        Logger.error("#{@log_prefix} Failed for item #{item_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: _args}) do
    Logger.info("#{@log_prefix} Starting full similarity computation")

    case fetch_active_items() do
      {:ok, items} ->
        Logger.info("#{@log_prefix} Computing similarities for #{length(items)} items")

        # Process in batches
        items
        |> Enum.chunk_every(@batch_size)
        |> Enum.with_index(1)
        |> Enum.each(fn {batch, batch_num} ->
          total_batches = ceil(length(items) / @batch_size)
          Logger.info("#{@log_prefix} Processing batch #{batch_num}/#{total_batches}")

          Enum.each(batch, &compute_and_save_similarities/1)
          Process.sleep(@batch_sleep_ms)
        end)

        Logger.info("#{@log_prefix} Complete")
        :ok

      {:error, reason} ->
        Logger.error("#{@log_prefix} Failed to fetch items: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helpers

  defp fetch_active_items do
    # Fetch published items only
    case Item
         |> Ash.Query.filter(publication_status == :published)
         |> Ash.Query.load(:category_id)
         |> Ash.read(authorize?: false) do
      {:ok, items} -> {:ok, items}
      {:error, reason} -> {:error, reason}
    end
  end

  defp compute_single_item(item_id) do
    with {:ok, source_item} <- fetch_item_by_id(item_id),
         {:ok, candidate_items} <- fetch_active_items() do
      compute_and_save_similarities(source_item, candidate_items)
    end
  end

  defp fetch_item_by_id(item_id) do
    case Item
         |> Ash.Query.filter(id == ^item_id)
         |> Ash.Query.load(:category_id)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, item} -> {:ok, item}
      {:error, reason} -> {:error, reason}
    end
  end

  defp compute_and_save_similarities(source_item) do
    case fetch_active_items() do
      {:ok, candidate_items} ->
        compute_and_save_similarities(source_item, candidate_items)

      {:error, reason} ->
        Logger.warning(
          "#{@log_prefix} Failed to fetch candidates for item #{source_item.id}: #{inspect(reason)}"
        )
    end
  end

  defp compute_and_save_similarities(source_item, candidate_items) do
    case SimilarityScorer.compute_similarities(source_item, candidate_items) do
      {:ok, similarities} ->
        # Take top N similar items
        top_similar = Enum.take(similarities, @top_n_similar)

        # Clear existing similarities for this item to avoid stale data
        clear_existing_similarities(source_item.id)

        # Save to database
        Enum.each(top_similar, fn {similar_item, score, reason} ->
          save_similarity(source_item.id, similar_item.id, score, reason)
        end)

        # Update cache with item IDs only (lightweight)
        similar_item_ids = Enum.map(top_similar, fn {item, _score, _reason} -> item.id end)
        Cache.put_similar_items(source_item.id, similar_item_ids)

        :ok

      {:error, reason} ->
        Logger.warning(
          "#{@log_prefix} Failed to compute similarities for item #{source_item.id}: #{inspect(reason)}"
        )
    end
  end

  defp clear_existing_similarities(source_item_id) do
    # Delete existing similarities to avoid duplicates
    # Note: This uses direct Ash operations. In production, consider adding a
    # bulk delete action to ItemSimilarity resource for better performance
    case ItemSimilarity
         |> Ash.Query.filter(source_item_id == ^source_item_id)
         |> Ash.read(authorize?: false) do
      {:ok, existing} ->
        Enum.each(existing, fn record ->
          Ash.destroy(record, authorize?: false)
        end)

      {:error, _reason} ->
        # Log but don't fail the job
        :ok
    end
  end

  defp save_similarity(source_item_id, similar_item_id, score, reason) do
    case ItemSimilarity.create_similarity(
           %{
             source_item_id: source_item_id,
             similar_item_id: similar_item_id,
             similarity_score: score,
             reason: reason
           },
           authorize?: false
         ) do
      {:ok, _record} ->
        :ok

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        # Check if it's a uniqueness constraint violation (duplicate)
        case Enum.any?(errors, &match?(%Ash.Error.Changes.InvalidAttribute{}, &1)) do
          true ->
            # Duplicate - try to update instead
            update_existing_similarity(source_item_id, similar_item_id, score, reason)

          false ->
            Logger.warning(
              "#{@log_prefix} Failed to save similarity #{source_item_id} -> #{similar_item_id}: #{inspect(errors)}"
            )
        end

      {:error, reason} ->
        Logger.warning(
          "#{@log_prefix} Failed to save similarity #{source_item_id} -> #{similar_item_id}: #{inspect(reason)}"
        )
    end
  end

  defp update_existing_similarity(source_item_id, similar_item_id, score, reason) do
    case ItemSimilarity
         |> Ash.Query.filter(
           source_item_id == ^source_item_id and similar_item_id == ^similar_item_id
         )
         |> Ash.read_one(authorize?: false) do
      {:ok, existing} when not is_nil(existing) ->
        existing
        |> Ash.Changeset.for_update(:update, %{
          similarity_score: score,
          reason: reason
        })
        |> Ash.update(authorize?: false)

      _ ->
        :ok
    end
  end
end
