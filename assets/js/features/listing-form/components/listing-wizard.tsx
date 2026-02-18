import { useReducer, useCallback } from "react";
import { router } from "@inertiajs/react";
import { ArrowLeft } from "lucide-react";
import { StepIndicator } from "./step-indicator";
import { BasicDetailsStep } from "./basic-details-step";
import { AuctionInfoStep } from "./auction-info-step";
import { LogisticsStep } from "./logistics-step";
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

interface InitialWizardData {
  draftItemId: string;
  basicDetails: BasicDetailsData;
  auctionInfo: AuctionInfoData;
  logistics: LogisticsData;
  uploadedImages: ListingFormState["uploadedImages"];
  step: 1 | 2 | 3;
}

interface ListingWizardProps {
  categories: Category[];
  storeProfile: { deliveryPreference: string | null } | null;
  initialData?: InitialWizardData;
}

export function ListingWizard({ categories, storeProfile, initialData }: ListingWizardProps) {
  const defaultDelivery = mapDeliveryPreference(storeProfile?.deliveryPreference);

  const [state, dispatch] = useReducer(listingFormReducer, {
    ...initialFormState,
    ...(initialData
      ? {
          currentStep: initialData.step,
          draftItemId: initialData.draftItemId,
          basicDetails: initialData.basicDetails,
          auctionInfo: initialData.auctionInfo,
          logistics: initialData.logistics,
          uploadedImages: initialData.uploadedImages,
        }
      : {
          logistics: { deliveryPreference: defaultDelivery },
        }),
  });

  const handleBasicDetailsNext = useCallback((data: BasicDetailsData, draftId: string, uploadedImages: ListingFormState["uploadedImages"]) => {
    dispatch({ type: "SET_BASIC_DETAILS", data });
    dispatch({ type: "SET_DRAFT_ID", id: draftId });
    dispatch({ type: "SET_UPLOADED_IMAGES", images: uploadedImages });
    dispatch({ type: "SET_STEP", step: 2 });
  }, []);

  const handleDeleteImage = useCallback((imageId: string) => {
    dispatch({ type: "REMOVE_UPLOADED_IMAGE", id: imageId });
  }, []);

  const handleAuctionInfoNext = useCallback((data: AuctionInfoData) => {
    dispatch({ type: "SET_AUCTION_INFO", data });
    dispatch({ type: "SET_STEP", step: 3 });
  }, []);

  const handleLogisticsNext = useCallback((data: LogisticsData) => {
    dispatch({ type: "SET_LOGISTICS", data });
    router.visit(`/store/listings/${state.draftItemId}/preview`);
  }, [state.draftItemId]);

  const handleBack = useCallback(() => {
    if (state.currentStep > 1) {
      dispatch({ type: "SET_STEP", step: (state.currentStep - 1) as ListingFormState["currentStep"] });
    }
  }, [state.currentStep]);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        {state.currentStep > 1 && (
          <button
            type="button"
            onClick={handleBack}
            className="mb-2 flex items-center gap-1 text-sm text-content-secondary hover:text-content"
          >
            <ArrowLeft className="size-4" />
            Back
          </button>
        )}
        <h1 className="text-xl font-bold text-content">List An Item</h1>
        <p className="mt-1 text-sm text-content-tertiary">
          Turn your item into cash by creating a quick listing
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
          onDeleteImage={handleDeleteImage}
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
          draftItemId={state.draftItemId!}
          defaultValues={state.logistics}
          onNext={handleLogisticsNext}
          onBack={handleBack}
        />
      )}
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
