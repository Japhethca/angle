defmodule Angle.Repo.Migrations.FixAuctionStatusCheckConstraint do
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE items DROP CONSTRAINT IF EXISTS valid_auction_status
    """

    execute """
    ALTER TABLE items ADD CONSTRAINT valid_auction_status
    CHECK (
      auction_status IS NULL
      OR (auction_status)::text = ANY (
        ARRAY[
          'pending', 'scheduled', 'active', 'paused',
          'ended', 'sold', 'cancelled'
        ]
      )
    )
    """
  end

  def down do
    execute """
    ALTER TABLE items DROP CONSTRAINT IF EXISTS valid_auction_status
    """

    execute """
    ALTER TABLE items ADD CONSTRAINT valid_auction_status
    CHECK (
      auction_status IS NULL
      OR (auction_status)::text = ANY (
        ARRAY[
          'scheduled', 'active', 'paused',
          'ended', 'sold', 'cancelled'
        ]
      )
    )
    """
  end
end
