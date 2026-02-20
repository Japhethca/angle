defmodule Angle.Accounts.User do
  require Ash.Resource.Preparation.Builtins
  require Ash.Query

  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshTypescript.Resource]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end

      confirmation :confirm_new_user do
        monitor_fields [:email]
        # Todo: change to confirm on create false
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        confirmed_at_field :confirmed_at
        auto_confirm_actions [:sign_in_with_magic_link, :password_reset_with_password]
        sender Angle.Accounts.User.Senders.SendNewUserConfirmationEmail
      end
    end

    tokens do
      enabled? true
      token_resource Angle.Accounts.Token
      signing_secret Angle.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password

        resettable do
          sender Angle.Accounts.User.Senders.SendPasswordResetEmail
        end
      end

      google do
        client_id Angle.Secrets
        redirect_uri Angle.Secrets
        client_secret Angle.Secrets
      end
    end
  end

  postgres do
    table "users"
    repo Angle.Repo
  end

  typescript do
    type_name "User"
  end

  actions do
    defaults [:read]

    create :register_with_google do
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      upsert? true
      upsert_identity :unique_email
      upsert_fields []

      change AshAuthentication.GenerateTokenChange
      change AshAuthentication.Strategy.OAuth2.IdentityChange

      change fn changeset, _ctx ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)

        changeset
        |> Ash.Changeset.change_attribute(:email, Map.get(user_info, "email"))
        |> Ash.Changeset.change_attribute(:full_name, Map.get(user_info, "name"))
        |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
      end

      # Auto-assign default "bidder" role after registration
      change after_action(fn _changeset, user, _context ->
               case Angle.Accounts.assign_role(user, %{role_name: "bidder"}, authorize?: false) do
                 {:ok, _} -> {:ok, user}
                 {:error, _} -> {:ok, user}
               end
             end)
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    update :change_password do
      # Use this action to allow users to change their password by providing
      # their current password and a new password.

      require_atomic? false
      accept []
      argument :current_password, :string, sensitive?: true, allow_nil?: false

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false

      validate confirm(:password, :password_confirmation)

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      # validates the provided email and password and generates a token
      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_token do
      # In the generated sign in components, we validate the
      # email and password directly in the LiveView
      # and generate a short-lived token that can be used to sign in over
      # a standard controller action, exchanging it for a standard token.
      # This action performs that exchange. If you do not use the generated
      # liveviews, you may remove this action, and set
      # `sign_in_tokens_enabled? false` in the password strategy.

      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      # validates the provided sign in token and generates a token
      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :register_with_password do
      description "Register a new user with a email and password."

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      argument :full_name, :string do
        description "The user's full name."
      end

      argument :phone_number, :string do
        description "The user's phone number."
      end

      # Sets the email from the argument
      change set_attribute(:email, arg(:email))

      # Sets optional profile fields
      change set_attribute(:full_name, arg(:full_name))
      change set_attribute(:phone_number, arg(:phone_number))

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      # Auto-assign default "bidder" role after registration
      change after_action(fn _changeset, user, _context ->
               case Angle.Accounts.assign_role(user, %{role_name: "bidder"}, authorize?: false) do
                 {:ok, _} -> {:ok, user}
                 {:error, _} -> {:ok, user}
               end
             end)

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    action :request_password_reset_token do
      description "Send password reset instructions to a user if they exist."

      argument :email, :ci_string do
        allow_nil? false
      end

      # creates a reset token and invokes the relevant senders
      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get? true

      argument :email, :ci_string do
        allow_nil? false
      end

      filter expr(email == ^arg(:email))
    end

    update :assign_role do
      description "Assign a role to the user"
      accept []
      require_atomic? false

      argument :role_name, :string do
        allow_nil? false
        description "The name of the role to assign"
      end

      argument :expires_at, :utc_datetime_usec do
        description "When the role assignment expires (optional)"
      end

      argument :granted_by_id, :uuid do
        description "ID of the user granting this role (optional)"
      end

      change fn changeset, _context ->
        role_name = Ash.Changeset.get_argument(changeset, :role_name)
        user_id = Ash.Changeset.get_attribute(changeset, :id)

        # Find the role by name
        case Ash.Query.filter(Angle.Accounts.Role, expr(name == ^role_name))
             |> Ash.read_one(domain: Angle.Accounts) do
          {:ok, nil} ->
            Ash.Changeset.add_error(changeset, field: :role_name, message: "Role not found")

          {:ok, role} ->
            # Create UserRole record
            user_role_attrs = %{
              user_id: user_id,
              role_id: role.id,
              expires_at: Ash.Changeset.get_argument(changeset, :expires_at),
              granted_by_id: Ash.Changeset.get_argument(changeset, :granted_by_id)
            }

            case Ash.create(Angle.Accounts.UserRole, user_role_attrs, domain: Angle.Accounts) do
              {:ok, _user_role} ->
                changeset

              {:error, _} ->
                Ash.Changeset.add_error(changeset,
                  field: :role_name,
                  message: "Role assignment failed"
                )
            end

          {:error, _} ->
            Ash.Changeset.add_error(changeset, field: :role_name, message: "Role not found")
        end
      end
    end

    update :remove_role do
      description "Remove a role from the user"
      accept []
      require_atomic? false

      argument :role_name, :string do
        allow_nil? false
        description "The name of the role to remove"
      end

      change fn changeset, _context ->
        role_name = Ash.Changeset.get_argument(changeset, :role_name)
        user_id = Ash.Changeset.get_attribute(changeset, :id)

        case Ash.Query.filter(Angle.Accounts.Role, expr(name == ^role_name))
             |> Ash.read_one(domain: Angle.Accounts) do
          {:ok, nil} ->
            Ash.Changeset.add_error(changeset, field: :role_name, message: "Role not found")

          {:ok, role} ->
            # Delete UserRole directly via Ecto (no primary key on UserRole)
            import Ecto.Query

            {deleted, _} =
              Angle.Repo.delete_all(
                from(ur in "user_roles",
                  where: ur.user_id == type(^user_id, :binary_id),
                  where: ur.role_id == type(^role.id, :binary_id)
                )
              )

            if deleted > 0 do
              changeset
            else
              Ash.Changeset.add_error(changeset,
                field: :role_name,
                message: "User does not have this role"
              )
            end

          {:error, _} ->
            Ash.Changeset.add_error(changeset, field: :role_name, message: "Role not found")
        end
      end
    end

    update :update_profile do
      description "Update the user's profile information"
      accept [:full_name, :phone_number, :location]
    end

    update :update_auto_charge do
      description "Update the user's auto-charge preference"
      accept [:auto_charge]
    end

    update :update_notification_preferences do
      description "Update the user's notification preferences"
      accept [:notification_preferences]
    end

    read :read_public_profile do
      description "Public read action for seller/store profiles"

      argument :username, :string
      argument :user_id, :uuid

      filter expr(
               (not is_nil(^arg(:username)) and username == ^arg(:username)) or
                 (not is_nil(^arg(:user_id)) and id == ^arg(:user_id))
             )

      pagination offset?: true, required?: false
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # Authentication actions - allow everyone
    policy action(:register_with_password) do
      authorize_if always()
    end

    policy action(:register_with_google) do
      authorize_if always()
    end

    policy action(:sign_in_with_password) do
      authorize_if always()
    end

    policy action(:sign_in_with_token) do
      authorize_if always()
    end

    policy action(:get_by_subject) do
      authorize_if always()
    end

    policy action(:request_password_reset_token) do
      authorize_if always()
    end

    policy action(:get_by_email) do
      authorize_if always()
    end

    policy action(:request_password_reset_with_password) do
      authorize_if always()
    end

    policy action(:password_reset_with_password) do
      authorize_if always()
    end

    # User data access - restricted
    policy action(:read) do
      # Users can only read themselves
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:read_public_profile) do
      authorize_if always()
    end

    policy action_type([:update]) do
      # Users can only update themselves
      authorize_if expr(id == ^actor(:id))
    end

    # Role management - requires manage_users permission
    policy action([:assign_role, :remove_role]) do
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "manage_users"}
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: true, sensitive?: true
    attribute :confirmed_at, :utc_datetime_usec
    attribute :full_name, :string, public?: true
    attribute :phone_number, :string, public?: true
    attribute :username, :string, public?: true
    attribute :location, :string, public?: true
    attribute :whatsapp_number, :string, public?: true
    attribute :auto_charge, :boolean, default: false, public?: true

    attribute :notification_preferences, Angle.Accounts.NotificationPreferences,
      default: %{},
      public?: true

    create_timestamp :created_at do
      allow_nil? false
      public? true
    end
  end

  relationships do
    has_many :user_roles, Angle.Accounts.UserRole do
      destination_attribute :user_id
      public? true
    end

    many_to_many :roles, Angle.Accounts.Role do
      through Angle.Accounts.UserRole
      destination_attribute_on_join_resource :role_id
      source_attribute_on_join_resource :user_id
      public? true
    end

    has_one :store_profile, Angle.Accounts.StoreProfile do
      destination_attribute :user_id
      public? true
    end

    has_many :items, Angle.Inventory.Item do
      destination_attribute :created_by_id
      public? true
    end

    has_many :received_reviews, Angle.Bidding.Review do
      destination_attribute :seller_id
      public? true
    end

    has_one :wallet, Angle.Payments.UserWallet do
      destination_attribute :user_id
      public? true
    end
  end

  calculations do
    calculate :has_role?, :boolean do
      description "Check if user has a specific role"

      argument :role_name, :string do
        allow_nil? false
      end

      calculation fn records, %{role_name: role_name} ->
        user_ids = Enum.map(records, & &1.id)

        # Get role by name
        case Ash.Query.filter(Angle.Accounts.Role, expr(name == ^role_name))
             |> Ash.read_one(domain: Angle.Accounts) do
          {:ok, role} ->
            # Find which users have this role
            now = DateTime.utc_now()

            user_roles =
              Ash.Query.filter(
                Angle.Accounts.UserRole,
                expr(
                  user_id in ^user_ids and
                    role_id == ^role.id and
                    (is_nil(expires_at) or expires_at > ^now)
                )
              )
              |> Ash.read!(domain: Angle.Accounts)

            users_with_role = MapSet.new(user_roles, & &1.user_id)

            Enum.map(records, fn record ->
              MapSet.member?(users_with_role, record.id)
            end)

          {:error, _} ->
            Enum.map(records, fn _ -> false end)
        end
      end
    end

    calculate :active_roles, {:array, :string} do
      description "Get list of user's active role names"

      calculation fn records, _context ->
        user_ids = Enum.map(records, & &1.id)

        # Get active user roles with role names
        now = DateTime.utc_now()

        user_roles =
          Ash.Query.filter(
            Angle.Accounts.UserRole,
            expr(
              user_id in ^user_ids and
                (is_nil(expires_at) or expires_at > ^now)
            )
          )
          |> Ash.Query.load(:role)
          |> Ash.read!(domain: Angle.Accounts)

        # Group by user_id
        roles_by_user = Enum.group_by(user_roles, & &1.user_id)

        Enum.map(records, fn record ->
          case Map.get(roles_by_user, record.id, []) do
            user_roles when is_list(user_roles) ->
              Enum.map(user_roles, fn ur -> ur.role.name end)

            _ ->
              []
          end
        end)
      end
    end

    calculate :has_permission?, :boolean do
      description "Check if user has a specific permission"

      argument :permission_name, :string do
        allow_nil? false
      end

      calculation fn records, %{permission_name: permission_name} ->
        user_ids = Enum.map(records, & &1.id)

        # Get user roles with permissions
        now = DateTime.utc_now()

        user_roles =
          Ash.Query.filter(
            Angle.Accounts.UserRole,
            expr(
              user_id in ^user_ids and
                (is_nil(expires_at) or expires_at > ^now)
            )
          )
          |> Ash.Query.load(role: :permissions)
          |> Ash.read!(domain: Angle.Accounts)

        # Extract all permissions for each user
        users_with_permission =
          user_roles
          |> Enum.group_by(& &1.user_id)
          |> Enum.filter(fn {_user_id, roles} ->
            roles
            |> Enum.flat_map(fn ur -> ur.role.permissions end)
            |> Enum.any?(fn perm -> perm.name == permission_name end)
          end)
          |> Enum.map(fn {user_id, _} -> user_id end)
          |> MapSet.new()

        Enum.map(records, fn record ->
          MapSet.member?(users_with_permission, record.id)
        end)
      end
    end
  end

  aggregates do
    count :published_item_count, :items do
      filter expr(publication_status == :published)
      public? true
    end

    count :review_count, :received_reviews do
      public? true
    end

    avg :avg_rating, :received_reviews, :rating do
      public? true
    end
  end

  identities do
    identity :unique_email, [:email]
    identity :unique_username, [:username]
  end
end
