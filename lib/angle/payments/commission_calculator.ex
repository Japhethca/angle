defmodule Angle.Payments.CommissionCalculator do
  @moduledoc """
  Calculates platform commission for auction sales based on tiered pricing:
  - 8% for amounts < ₦50,000
  - 6% for amounts ₦50,000 - ₦199,999.99
  - 5% for amounts ≥ ₦200,000
  """

  @tier_1_threshold Decimal.new("50000")
  @tier_2_threshold Decimal.new("200000")

  # 8%
  @tier_1_rate Decimal.new("0.08")
  # 6%
  @tier_2_rate Decimal.new("0.06")
  # 5%
  @tier_3_rate Decimal.new("0.05")

  @doc """
  Calculates commission amount for a given transaction amount.

  ## Examples

      iex> CommissionCalculator.calculate_commission(Decimal.new("25000"))
      #Decimal<2000>

      iex> CommissionCalculator.calculate_commission(Decimal.new("100000"))
      #Decimal<6000>

      iex> CommissionCalculator.calculate_commission(Decimal.new("250000"))
      #Decimal<12500>
  """
  def calculate_commission(amount) when is_struct(amount, Decimal) do
    rate = commission_rate(amount)

    amount
    |> Decimal.mult(rate)
    |> Decimal.round(2)
  end

  @doc """
  Returns the commission rate for a given amount.
  """
  def commission_rate(amount) when is_struct(amount, Decimal) do
    cond do
      Decimal.lt?(amount, @tier_1_threshold) -> @tier_1_rate
      Decimal.lt?(amount, @tier_2_threshold) -> @tier_2_rate
      true -> @tier_3_rate
    end
  end

  @doc """
  Calculates net amount after commission deduction.

  ## Examples

      iex> CommissionCalculator.calculate_net_amount(Decimal.new("100000"))
      #Decimal<94000>
  """
  def calculate_net_amount(amount) when is_struct(amount, Decimal) do
    commission = calculate_commission(amount)
    Decimal.sub(amount, commission)
  end
end
