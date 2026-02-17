import { z } from "zod";

export const basicDetailsSchema = z.object({
  title: z.string().min(1, "Title is required").max(200),
  description: z.string().optional().default(""),
  categoryId: z.string().min(1, "Category is required"),
  subcategoryId: z.string().optional().default(""),
  condition: z.enum(["new", "used", "refurbished"]),
  attributes: z.record(z.string(), z.string()).default({}),
  customFeatures: z.array(z.string()).default([]),
});

export const auctionInfoSchema = z.object({
  startingPrice: z.string().min(1, "Starting price is required").refine(
    (val) => !isNaN(Number(val)) && Number(val) > 0,
    "Must be a positive number"
  ),
  reservePrice: z.string().optional().default(""),
  auctionDuration: z.enum(["24h", "3d", "7d"]),
});

export const logisticsSchema = z.object({
  deliveryPreference: z.enum(["meetup", "buyer_arranges", "seller_arranges"]),
});

export type BasicDetailsData = z.infer<typeof basicDetailsSchema>;
export type AuctionInfoData = z.infer<typeof auctionInfoSchema>;
export type LogisticsData = z.infer<typeof logisticsSchema>;

export type ListingFormState = {
  currentStep: 1 | 2 | 3 | 4;
  draftItemId: string | null;
  basicDetails: BasicDetailsData;
  auctionInfo: AuctionInfoData;
  logistics: LogisticsData;
  selectedImages: File[];
  uploadedImages: Array<{ id: string; position: number; variants: Record<string, string> }>;
  isSubmitting: boolean;
  isPublished: boolean;
};

export type ListingFormAction =
  | { type: "SET_STEP"; step: 1 | 2 | 3 | 4 }
  | { type: "SET_DRAFT_ID"; id: string }
  | { type: "SET_BASIC_DETAILS"; data: BasicDetailsData }
  | { type: "SET_AUCTION_INFO"; data: AuctionInfoData }
  | { type: "SET_LOGISTICS"; data: LogisticsData }
  | { type: "SET_SELECTED_IMAGES"; files: File[] }
  | { type: "SET_UPLOADED_IMAGES"; images: ListingFormState["uploadedImages"] }
  | { type: "SET_SUBMITTING"; value: boolean }
  | { type: "SET_PUBLISHED"; value: boolean };

export const initialFormState: ListingFormState = {
  currentStep: 1,
  draftItemId: null,
  basicDetails: {
    title: "",
    description: "",
    categoryId: "",
    subcategoryId: "",
    condition: "used",
    attributes: {},
    customFeatures: ["", "", ""],
  },
  auctionInfo: {
    startingPrice: "",
    reservePrice: "",
    auctionDuration: "7d",
  },
  logistics: {
    deliveryPreference: "buyer_arranges",
  },
  selectedImages: [],
  uploadedImages: [],
  isSubmitting: false,
  isPublished: false,
};

export function listingFormReducer(
  state: ListingFormState,
  action: ListingFormAction
): ListingFormState {
  switch (action.type) {
    case "SET_STEP":
      return { ...state, currentStep: action.step };
    case "SET_DRAFT_ID":
      return { ...state, draftItemId: action.id };
    case "SET_BASIC_DETAILS":
      return { ...state, basicDetails: action.data };
    case "SET_AUCTION_INFO":
      return { ...state, auctionInfo: action.data };
    case "SET_LOGISTICS":
      return { ...state, logistics: action.data };
    case "SET_SELECTED_IMAGES":
      return { ...state, selectedImages: action.files };
    case "SET_UPLOADED_IMAGES":
      return { ...state, uploadedImages: action.images };
    case "SET_SUBMITTING":
      return { ...state, isSubmitting: action.value };
    case "SET_PUBLISHED":
      return { ...state, isPublished: action.value };
    default:
      return state;
  }
}
