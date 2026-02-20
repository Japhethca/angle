defmodule Angle.Accounts.UserVerification do
  use Ash.Resource,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @otp_test_mode Application.compile_env(:angle, :otp_test_mode, false)

  postgres do
    table "user_verifications"
    repo Angle.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:user_id]
    end

    update :request_phone_otp do
      require_atomic? false
      argument :phone_number, :string, allow_nil?: false

      change fn changeset, _context ->
        phone_number = Ash.Changeset.get_argument(changeset, :phone_number)
        last_requested = Ash.Changeset.get_attribute(changeset, :otp_requested_at)

        # Rate limit: max 1 OTP per minute
        if not is_nil(last_requested) and
             DateTime.diff(DateTime.utc_now(), last_requested, :second) < 60 do
          Ash.Changeset.add_error(
            changeset,
            message: "Please wait before requesting another OTP"
          )
        else
          # Generate 6-digit OTP
          otp_code = generate_otp()
          otp_hash = hash_otp(otp_code)
          expires_at = DateTime.add(DateTime.utc_now(), 5 * 60, :second)

          changeset =
            changeset
            |> Ash.Changeset.force_change_attribute(:phone_number, phone_number)
            |> Ash.Changeset.force_change_attribute(:otp_hash, otp_hash)
            |> Ash.Changeset.force_change_attribute(:otp_expires_at, expires_at)
            |> Ash.Changeset.force_change_attribute(:otp_requested_at, DateTime.utc_now())

          # In test/dev: return OTP in result
          # In prod: send via SMS, don't return OTP
          if @otp_test_mode do
            changeset
            |> Ash.Changeset.after_action(fn _changeset, verification ->
              {:ok, Map.put(verification, :otp_code, otp_code)}
            end)
          else
            # TODO: Send SMS via Termii/Africa's Talking
            # send_sms(phone_number, "Your Angle verification code: #{otp_code}")

            changeset
          end
        end
      end
    end

    update :verify_phone_otp do
      require_atomic? false
      argument :otp_code, :string, allow_nil?: false

      change fn changeset, _context ->
        submitted_otp = Ash.Changeset.get_argument(changeset, :otp_code)
        stored_hash = Ash.Changeset.get_attribute(changeset, :otp_hash)
        expires_at = Ash.Changeset.get_attribute(changeset, :otp_expires_at)

        cond do
          is_nil(stored_hash) or is_nil(expires_at) ->
            Ash.Changeset.add_error(
              changeset,
              message: "No OTP requested. Please request an OTP first."
            )

          DateTime.compare(DateTime.utc_now(), expires_at) == :gt ->
            Ash.Changeset.add_error(
              changeset,
              message: "OTP expired. Please request a new one."
            )

          not Plug.Crypto.secure_compare(hash_otp(submitted_otp), stored_hash) ->
            Ash.Changeset.add_error(
              changeset,
              message: "Invalid OTP code"
            )

          true ->
            # OTP valid - mark phone as verified
            changeset
            |> Ash.Changeset.force_change_attribute(:phone_verified, true)
            |> Ash.Changeset.force_change_attribute(:phone_verified_at, DateTime.utc_now())
            # Clear OTP data
            |> Ash.Changeset.force_change_attribute(:otp_hash, nil)
            |> Ash.Changeset.force_change_attribute(:otp_expires_at, nil)
        end
      end
    end

    update :submit_id_document do
      require_atomic? false
      argument :id_document_url, :string, allow_nil?: false

      change fn changeset, _context ->
        document_url = Ash.Changeset.get_argument(changeset, :id_document_url)
        current_status = Ash.Changeset.get_attribute(changeset, :id_verification_status)

        # Prevent resubmission if already approved
        if current_status == :approved do
          Ash.Changeset.add_error(
            changeset,
            message: "ID already approved, cannot resubmit"
          )
        else
          changeset
          |> Ash.Changeset.force_change_attribute(:id_document_url, document_url)
          |> Ash.Changeset.force_change_attribute(:id_verification_status, :pending)
          |> Ash.Changeset.force_change_attribute(:id_rejection_reason, nil)
        end
      end
    end

    update :approve_id do
      require_atomic? false

      validate attribute_equals(:id_verification_status, :pending),
        message: "can only approve pending ID documents"

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:id_verification_status, :approved)
        |> Ash.Changeset.force_change_attribute(:id_verified, true)
        |> Ash.Changeset.force_change_attribute(:id_verified_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:id_rejection_reason, nil)
      end
    end

    update :reject_id do
      require_atomic? false
      argument :reason, :string, allow_nil?: false

      validate attribute_equals(:id_verification_status, :pending),
        message: "can only reject pending ID documents"

      change fn changeset, _context ->
        reason = Ash.Changeset.get_argument(changeset, :reason)

        changeset
        |> Ash.Changeset.force_change_attribute(:id_verification_status, :rejected)
        |> Ash.Changeset.force_change_attribute(:id_verified, false)
        |> Ash.Changeset.force_change_attribute(:id_rejection_reason, reason)
      end
    end
  end

  policies do
    policy action_type(:read) do
      # Users can read their own verification
      authorize_if expr(user_id == ^actor(:id))

      # Admins can read all verifications
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "admin"}
    end

    policy action_type([:create, :update, :destroy]) do
      # Only admins can modify verification records
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "admin"}
    end
  end

  attributes do
    uuid_primary_key :id

    # Phone verification
    attribute :phone_verified, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :phone_verified_at, :utc_datetime_usec do
      public? true
    end

    # OTP fields (internal - not public)
    attribute :phone_number, :string do
      public? true
    end

    attribute :otp_hash, :string

    attribute :otp_expires_at, :utc_datetime_usec

    attribute :otp_requested_at, :utc_datetime_usec

    # ID verification
    attribute :id_verified, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :id_document_url, :string do
      public? true
    end

    attribute :id_verified_at, :utc_datetime_usec do
      public? true
    end

    attribute :id_verification_status, :atom do
      allow_nil? false
      public? true
      default :not_submitted
      constraints one_of: [:not_submitted, :pending, :approved, :rejected]
    end

    attribute :id_rejection_reason, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      public? true
      attribute_writable? true
      # TODO: Add ON DELETE CASCADE to foreign key constraint in a future migration
      # to prevent orphaned verification records when a user is deleted
    end
  end

  identities do
    identity :unique_user_verification, [:user_id]
  end

  # Helper functions for OTP
  defp generate_otp do
    :crypto.strong_rand_bytes(4)
    |> :binary.decode_unsigned()
    |> rem(1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp hash_otp(otp_code) do
    :crypto.hash(:sha256, otp_code)
    |> Base.encode16(case: :lower)
  end
end
