defmodule Angle.Bidding.Review.ValidateEditWindow do
  @moduledoc "Validates that the review edit is within 7 days of creation."
  use Ash.Resource.Change

  @edit_window_days 7

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      review = changeset.data
      cutoff = DateTime.add(review.inserted_at, @edit_window_days * 24 * 3600)

      if DateTime.compare(DateTime.utc_now(), cutoff) == :lt do
        changeset
      else
        Ash.Changeset.add_error(changeset,
          field: :rating,
          message: "Edit window has expired (7 days after review creation)"
        )
      end
    end)
  end
end
