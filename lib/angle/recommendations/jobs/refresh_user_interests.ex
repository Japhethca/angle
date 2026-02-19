defmodule Angle.Recommendations.Jobs.RefreshUserInterests do
  @moduledoc """
  Background job to refresh user interest profiles based on recent activity.

  Runs hourly to compute interest scores for active users and update their
  UserInterest records. Uses InterestScorer to analyze bids and watchlist
  activity across categories.

  ## Processing Strategy
  - Targets users with last_sign_in_at within 30 days
  - Processes in batches of 100 users
  - 100ms sleep between batches for rate limiting
  - Creates new or updates existing UserInterest records

  ## Oban Configuration
  - Queue: :recommendations
  - Max attempts: 3
  - Uniqueness: 1 hour period (prevents duplicate runs)
  """

  use Oban.Worker,
    queue: :recommendations,
    max_attempts: 3,
    unique: [period: 3600]

  alias Angle.Recommendations.Scoring.InterestScorer
  require Ash.Query
  require Logger

  @active_user_days 30
  @batch_size 100
  @batch_sleep_ms 100

  @doc """
  Performs the user interest refresh job.

  Fetches active users, computes their interest scores using InterestScorer,
  and upserts UserInterest records for each category with activity.

  ## Return values
  - `:ok` on successful completion
  - `{:error, reason}` if critical failure occurs
  """
  @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    Logger.info("[RefreshUserInterests] Starting user interests refresh")

    case fetch_active_users() do
      {:ok, active_users} ->
        Logger.info(
          "[RefreshUserInterests] Refreshing interests for #{length(active_users)} users"
        )

        # Process in batches
        active_users
        |> Enum.chunk_every(@batch_size)
        |> Enum.each(fn batch ->
          Enum.each(batch, &compute_and_save_interests/1)
          Process.sleep(@batch_sleep_ms)
        end)

        Logger.info("[RefreshUserInterests] Complete")
        :ok

      {:error, reason} ->
        Logger.error("[RefreshUserInterests] Failed to fetch active users: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helpers

  defp fetch_active_users do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-@active_user_days, :day)

    case Angle.Accounts.User
         |> Ash.Query.filter(last_sign_in_at > ^cutoff_date)
         |> Ash.read(authorize?: false) do
      {:ok, users} -> {:ok, users}
      {:error, reason} -> {:error, reason}
    end
  end

  defp compute_and_save_interests(user) do
    case InterestScorer.compute_user_interests(user.id) do
      {:ok, interests} ->
        Enum.each(interests, fn {category_id, score, count, last_interaction} ->
          upsert_user_interest(user.id, category_id, score, count, last_interaction)
        end)

      {:error, reason} ->
        Logger.warning(
          "[RefreshUserInterests] Failed to compute interests for user #{user.id}: #{inspect(reason)}"
        )
    end
  end

  defp upsert_user_interest(user_id, category_id, score, count, last_interaction) do
    case Angle.Recommendations.UserInterest
         |> Ash.Query.filter(user_id == ^user_id and category_id == ^category_id)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} ->
        # Create new record
        Angle.Recommendations.UserInterest
        |> Ash.Changeset.for_create(:create, %{
          user_id: user_id,
          category_id: category_id,
          interest_score: score,
          interaction_count: count,
          last_interaction_at: last_interaction
        })
        |> Ash.create(authorize?: false)

      {:ok, existing} ->
        # Update existing record
        existing
        |> Ash.Changeset.for_update(:update, %{
          interest_score: score,
          interaction_count: count,
          last_interaction_at: last_interaction
        })
        |> Ash.update(authorize?: false)

      {:error, reason} ->
        Logger.warning(
          "[RefreshUserInterests] Failed to read UserInterest for user #{user_id}, category #{category_id}: #{inspect(reason)}"
        )
    end
  end
end
