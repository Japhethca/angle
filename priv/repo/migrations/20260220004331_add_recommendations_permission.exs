defmodule Angle.Repo.Migrations.AddRecommendationsPermission do
  use Ecto.Migration

  def up do
    # Create permission using raw SQL
    execute """
    INSERT INTO permissions (id, name, resource, action, scope, description, created_at, updated_at)
    VALUES (
      gen_random_uuid(),
      'manage_recommendations',
      'recommendation',
      'all',
      'system',
      'Can manage recommendation data (admin only)',
      NOW(),
      NOW()
    )
    ON CONFLICT (name, resource, action) DO NOTHING
    """
  end

  def down do
    execute "DELETE FROM permissions WHERE name = 'manage_recommendations'"
  end
end
