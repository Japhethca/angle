import { useReducer, useCallback } from "react";
import { ArrowLeft } from "lucide-react";
import { StepIndicator } from "./step-indicator";
import { BasicDetailsStep } from "./basic-details-step";
import { AuctionInfoStep } from "./auction-info-step";
import { LogisticsStep } from "./logistics-step";
import { PreviewStep } from "./preview-step";
import { SuccessModal } from "./success-modal";
import {
  listingFormReducer,
  initialFormState,
  type ListingFormState,
  type BasicDetailsData,
  type AuctionInfoData,
  type LogisticsData,
} from "../schemas/listing-form-schema";

interface CategoryField {
  name: string;
  type: string;
  required?: boolean;
  description?: string | null;
  optionSetSlug?: string | null;
  options?: string[] | null;
}

interface Subcategory {
  id: string;
  name: string;
  slug: string | null;
  attributeSchema: CategoryField[];
}

export interface Category {
  id: string;
  name: string;
  slug: string | null;
  attributeSchema: CategoryField[];
  categories: Subcategory[];
}

interface ListingWizardProps {
  categories: Category[];
  storeProfile: { deliveryPreference: string | null } | null;
}

export function ListingWizard({ categories, storeProfile }: ListingWizardProps) {
  const defaultDelivery = mapDeliveryPreference(storeProfile?.deliveryPreference);

  const [state, dispatch] = useReducer(listingFormReducer, {
    ...initialFormState,
    logistics: { deliveryPreference: defaultDelivery },
  });

  const goToStep = useCallback((step: ListingFormState["currentStep"]) => {
    dispatch({ type: "SET_STEP", step });
  }, []);

  const handleBasicDetailsNext = useCallback((data: BasicDetailsData, draftId: string, uploadedImages: ListingFormState["uploadedImages"]) => {
    dispatch({ type: "SET_BASIC_DETAILS", data });
    dispatch({ type: "SET_DRAFT_ID", id: draftId });
    dispatch({ type: "SET_UPLOADED_IMAGES", images: uploadedImages });
    dispatch({ type: "SET_STEP", step: 2 });
  }, []);

  const handleAuctionInfoNext = useCallback((data: AuctionInfoData) => {
    dispatch({ type: "SET_AUCTION_INFO", data });
    dispatch({ type: "SET_STEP", step: 3 });
  }, []);

  const handleLogisticsNext = useCallback((data: LogisticsData) => {
    dispatch({ type: "SET_LOGISTICS", data });
    dispatch({ type: "SET_STEP", step: 4 });
  }, []);

  const handlePublished = useCallback(() => {
    dispatch({ type: "SET_PUBLISHED", value: true });
  }, []);

  const handleBack = useCallback(() => {
    if (state.currentStep > 1) {
      dispatch({ type: "SET_STEP", step: (state.currentStep - 1) as ListingFormState["currentStep"] });
    }
  }, [state.currentStep]);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        {state.currentStep > 1 && state.currentStep < 4 && (
          <button
            type="button"
            onClick={handleBack}
            className="mb-2 flex items-center gap-1 text-sm text-content-secondary hover:text-content"
          >
            <ArrowLeft className="size-4" />
            Back
          </button>
        )}
        <h1 className="text-xl font-bold text-content">
          {state.currentStep === 4 ? "Preview Listing" : "List An Item"}
        </h1>
        <p className="mt-1 text-sm text-content-tertiary">
          {state.currentStep === 4
            ? "Make sure everything looks good before you publish."
            : "Turn your item into cash by creating a quick listing"}
        </p>
      </div>

      {/* Step indicator */}
      <StepIndicator currentStep={state.currentStep} />

      {/* Step content */}
      {state.currentStep === 1 && (
        <BasicDetailsStep
          categories={categories}
          defaultValues={state.basicDetails}
          defaultImages={state.selectedImages}
          draftItemId={state.draftItemId}
          uploadedImages={state.uploadedImages}
          onNext={handleBasicDetailsNext}
        />
      )}
      {state.currentStep === 2 && (
        <AuctionInfoStep
          draftItemId={state.draftItemId!}
          defaultValues={state.auctionInfo}
          onNext={handleAuctionInfoNext}
          onBack={handleBack}
        />
      )}
      {state.currentStep === 3 && (
        <LogisticsStep
          defaultValues={state.logistics}
          onNext={handleLogisticsNext}
          onBack={handleBack}
        />
      )}
      {state.currentStep === 4 && (
        <PreviewStep
          state={state}
          categories={categories}
          onEdit={goToStep}
          onPublished={handlePublished}
        />
      )}

      {/* Success modal */}
      <SuccessModal
        open={state.isPublished}
        itemId={state.draftItemId}
      />
    </div>
  );
}

function mapDeliveryPreference(pref: string | null | undefined): "meetup" | "buyer_arranges" | "seller_arranges" {
  switch (pref) {
    case "pickup_only": return "meetup";
    case "seller_delivers": return "seller_arranges";
    case "you_arrange":
    default: return "buyer_arranges";
  }
}
