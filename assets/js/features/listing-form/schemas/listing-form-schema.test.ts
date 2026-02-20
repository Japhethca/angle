import { describe, it, expect } from "vitest";
import { logisticsSchema } from "./listing-form-schema";

describe("logisticsSchema", () => {
  it("validates delivery preference is required", () => {
    const result = logisticsSchema.safeParse({
      deliveryPreference: "meetup",
      location: { state: "Lagos" },
    });
    expect(result.success).toBe(true);
  });

  it("requires state in location", () => {
    const result = logisticsSchema.safeParse({
      deliveryPreference: "meetup",
      location: { state: "" },
    });
    expect(result.success).toBe(false);
    expect(result.error?.issues[0].path).toEqual(["location", "state"]);
  });

  it("allows LGA to be optional", () => {
    const result = logisticsSchema.safeParse({
      deliveryPreference: "meetup",
      location: { state: "Lagos" },
    });
    expect(result.success).toBe(true);
  });

  it("accepts state with LGA", () => {
    const result = logisticsSchema.safeParse({
      deliveryPreference: "meetup",
      location: { state: "Lagos", lga: "Ikeja" },
    });
    expect(result.success).toBe(true);
  });
});
