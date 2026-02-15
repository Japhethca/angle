defmodule Angle.Accounts.NotificationPreferences do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    # Push notifications
    attribute :push_bidding, :boolean do
      default true
      allow_nil? false
      public? true
    end

    attribute :push_watchlist, :boolean do
      default true
      allow_nil? false
      public? true
    end

    attribute :push_payments, :boolean do
      default true
      allow_nil? false
      public? true
    end

    attribute :push_communication, :boolean do
      default true
      allow_nil? false
      public? true
    end

    # Email notifications
    attribute :email_communication, :boolean do
      default true
      allow_nil? false
      public? true
    end

    attribute :email_marketing, :boolean do
      default true
      allow_nil? false
      public? true
    end

    attribute :email_security, :boolean do
      default true
      allow_nil? false
      public? true
    end

    # SMS notifications
    attribute :sms_communication, :boolean do
      default true
      allow_nil? false
      public? true
    end

    attribute :sms_security, :boolean do
      default true
      allow_nil? false
      public? true
    end
  end
end
