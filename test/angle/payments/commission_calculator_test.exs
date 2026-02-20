defmodule Angle.Payments.CommissionCalculatorTest do
  use Angle.DataCase, async: true

  alias Angle.Payments.CommissionCalculator

  describe "calculate_commission/1" do
    test "returns 8% for amounts less than ₦50,000" do
      amount = Decimal.new("25000")
      commission = CommissionCalculator.calculate_commission(amount)

      assert Decimal.eq?(commission, Decimal.new("2000"))
    end

    test "returns 8% for amounts equal to ₦49,999.99" do
      amount = Decimal.new("49999.99")
      commission = CommissionCalculator.calculate_commission(amount)

      # Commission is rounded to 2 decimal places for financial precision
      assert Decimal.eq?(commission, Decimal.new("4000.00"))
    end

    test "returns 6% for amounts between ₦50k and ₦200k" do
      amount = Decimal.new("100000")
      commission = CommissionCalculator.calculate_commission(amount)

      assert Decimal.eq?(commission, Decimal.new("6000"))
    end

    test "returns 6% for amounts equal to ₦199,999.99" do
      amount = Decimal.new("199999.99")
      commission = CommissionCalculator.calculate_commission(amount)

      assert Decimal.eq?(commission, Decimal.new("11999.9994"))
    end

    test "returns 5% for amounts greater than or equal to ₦200k" do
      amount = Decimal.new("250000")
      commission = CommissionCalculator.calculate_commission(amount)

      assert Decimal.eq?(commission, Decimal.new("12500"))
    end

    test "handles decimal precision correctly" do
      amount = Decimal.new("75432.50")
      commission = CommissionCalculator.calculate_commission(amount)

      assert Decimal.eq?(commission, Decimal.new("4525.95"))
    end
  end

  describe "calculate_net_amount/1" do
    test "returns amount after commission deduction" do
      amount = Decimal.new("100000")
      net_amount = CommissionCalculator.calculate_net_amount(amount)

      # ₦100,000 - 6% (₦6,000) = ₦94,000
      assert Decimal.eq?(net_amount, Decimal.new("94000"))
    end
  end

  describe "commission_rate/1" do
    test "returns 0.08 for amounts < ₦50k" do
      assert CommissionCalculator.commission_rate(Decimal.new("30000")) == Decimal.new("0.08")
    end

    test "returns 0.06 for amounts ₦50k-₦200k" do
      assert CommissionCalculator.commission_rate(Decimal.new("100000")) == Decimal.new("0.06")
    end

    test "returns 0.05 for amounts > ₦200k" do
      assert CommissionCalculator.commission_rate(Decimal.new("300000")) == Decimal.new("0.05")
    end
  end
end
