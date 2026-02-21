import { useState, useCallback } from "react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { useAshMutation } from "@/hooks/use-ash-query";
import { buildCSRFHeaders } from "@/ash_rpc";
import { toast } from "sonner";
import { router } from "@inertiajs/react";
import {
  Upload,
  CheckCircle2,
  XCircle,
  Clock,
  AlertCircle,
  FileText,
} from "lucide-react";
import { cn } from "@/lib/utils";

interface IdUploadProps {
  verificationId: string;
  idDocumentUrl?: string | null;
  idVerificationStatus: "not_submitted" | "pending" | "approved" | "rejected";
  idVerified: boolean;
  idVerifiedAt?: string | null;
  idRejectionReason?: string | null;
  onUploadSuccess?: () => void;
}

export function IdUpload({
  verificationId,
  idDocumentUrl,
  idVerificationStatus,
  idVerified,
  idVerifiedAt,
  idRejectionReason,
  onUploadSuccess,
}: IdUploadProps) {
  const [isDragging, setIsDragging] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  // For now, we'll use a manual approach since the RPC action needs policy updates
  // TODO: Replace with submitIdDocument once policies are updated to allow user access
  const uploadMutation = useAshMutation(
    async (documentUrl: string) => {
      // This will need to be replaced with the actual submitIdDocument RPC call
      // once the policies are updated
      const response = await fetch("/api/verification/upload-id", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...buildCSRFHeaders(),
        },
        body: JSON.stringify({
          verification_id: verificationId,
          id_document_url: documentUrl,
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.message || "Failed to upload ID document");
      }

      return response.json();
    },
    {
      onSuccess: () => {
        toast.success("ID document uploaded successfully! Pending admin review.");
        setSelectedFile(null);
        setPreviewUrl(null);
        if (onUploadSuccess) {
          onUploadSuccess();
        }
        router.reload();
      },
      onError: (error) => {
        toast.error(error.message || "Failed to upload ID document");
      },
    }
  );

  const validateFile = (file: File): string | null => {
    const validTypes = ["image/jpeg", "image/png", "image/jpg", "application/pdf"];
    const maxSize = 5 * 1024 * 1024; // 5MB

    if (!validTypes.includes(file.type)) {
      return "Please upload a JPG, PNG, or PDF file";
    }

    if (file.size > maxSize) {
      return "File size must be less than 5MB";
    }

    return null;
  };

  const handleFileChange = useCallback((file: File | null) => {
    if (!file) {
      setSelectedFile(null);
      setPreviewUrl(null);
      return;
    }

    const error = validateFile(file);
    if (error) {
      toast.error(error);
      return;
    }

    setSelectedFile(file);

    // Create preview for images
    if (file.type.startsWith("image/")) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setPreviewUrl(reader.result as string);
      };
      reader.readAsDataURL(file);
    } else {
      setPreviewUrl(null);
    }
  }, []);

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = () => {
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);

    const file = e.dataTransfer.files[0];
    if (file) {
      handleFileChange(file);
    }
  };

  const handleFileInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      handleFileChange(file);
    }
  };

  const handleUpload = async () => {
    if (!selectedFile) return;

    try {
      // Convert file to base64
      const reader = new FileReader();
      reader.onloadend = () => {
        const base64 = reader.result as string;
        // In a real implementation, this would upload to S3 and get a URL
        // For now, we'll use the base64 as a placeholder
        uploadMutation.mutate(base64);
      };
      reader.readAsDataURL(selectedFile);
    } catch (error) {
      toast.error("Failed to process file");
    }
  };

  const handleResubmit = () => {
    // Reset to allow resubmission
    setSelectedFile(null);
    setPreviewUrl(null);
  };

  // Status badge component
  const StatusBadge = () => {
    switch (idVerificationStatus) {
      case "approved":
        return (
          <div className="inline-flex items-center gap-2 rounded-lg border border-green-200 bg-green-50 px-3 py-2 text-sm">
            <CheckCircle2 className="h-4 w-4 text-green-600" />
            <div>
              <p className="font-medium text-green-900">Approved</p>
              {idVerifiedAt && (
                <p className="text-xs text-green-700">
                  Verified {new Date(idVerifiedAt).toLocaleDateString()}
                </p>
              )}
            </div>
          </div>
        );
      case "pending":
        return (
          <div className="inline-flex items-center gap-2 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm">
            <Clock className="h-4 w-4 text-amber-600" />
            <div>
              <p className="font-medium text-amber-900">Pending Review</p>
              <p className="text-xs text-amber-700">
                Your ID is being reviewed by our team
              </p>
            </div>
          </div>
        );
      case "rejected":
        return (
          <div className="rounded-lg border border-red-200 bg-red-50 p-3">
            <div className="flex items-start gap-2">
              <XCircle className="h-5 w-5 text-red-600 flex-shrink-0 mt-0.5" />
              <div className="flex-1">
                <p className="font-medium text-red-900">Rejected</p>
                {idRejectionReason && (
                  <p className="text-sm text-red-700 mt-1">
                    Reason: {idRejectionReason}
                  </p>
                )}
                <p className="text-xs text-red-600 mt-2">
                  Please upload a new document
                </p>
              </div>
            </div>
          </div>
        );
      default:
        return null;
    }
  };

  // If approved, show status only
  if (idVerificationStatus === "approved" && idVerified) {
    return (
      <div className="space-y-4">
        <StatusBadge />
        {idDocumentUrl && (
          <div className="text-sm text-muted-foreground">
            <p className="flex items-center gap-2">
              <FileText className="h-4 w-4" />
              Document on file
            </p>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Show status badge for pending or rejected */}
      {(idVerificationStatus === "pending" || idVerificationStatus === "rejected") && (
        <StatusBadge />
      )}

      {/* Only show upload UI if not pending or if rejected (allow resubmit) */}
      {(idVerificationStatus === "not_submitted" || idVerificationStatus === "rejected") && (
        <>
          <div>
            <Label>Government ID Document</Label>
            <p className="text-sm text-muted-foreground mb-3">
              Upload a clear photo of your government-issued ID (National ID, Driver's
              License, or Passport). Maximum 5MB.
            </p>

            {/* Drag-drop zone */}
            <div
              onDragOver={handleDragOver}
              onDragLeave={handleDragLeave}
              onDrop={handleDrop}
              className={cn(
                "relative rounded-lg border-2 border-dashed p-8 text-center transition-colors",
                isDragging
                  ? "border-primary bg-primary/5"
                  : "border-muted-foreground/25 hover:border-primary/50",
                uploadMutation.isPending && "opacity-50 pointer-events-none"
              )}
            >
              <input
                type="file"
                id="id-document-input"
                accept="image/jpeg,image/png,image/jpg,application/pdf"
                onChange={handleFileInputChange}
                className="hidden"
                disabled={uploadMutation.isPending}
              />

              {selectedFile ? (
                <div className="space-y-3">
                  {previewUrl && (
                    <div className="mx-auto w-48 h-32 relative rounded overflow-hidden border">
                      <img
                        src={previewUrl}
                        alt="Preview"
                        className="w-full h-full object-cover"
                      />
                    </div>
                  )}
                  {!previewUrl && selectedFile.type === "application/pdf" && (
                    <FileText className="h-12 w-12 mx-auto text-muted-foreground" />
                  )}
                  <p className="text-sm font-medium">{selectedFile.name}</p>
                  <p className="text-xs text-muted-foreground">
                    {(selectedFile.size / 1024 / 1024).toFixed(2)} MB
                  </p>
                  <div className="flex gap-2 justify-center">
                    <Button onClick={handleUpload} disabled={uploadMutation.isPending}>
                      {uploadMutation.isPending ? "Uploading..." : "Upload Document"}
                    </Button>
                    <Button
                      variant="outline"
                      onClick={() => handleFileChange(null)}
                      disabled={uploadMutation.isPending}
                    >
                      Cancel
                    </Button>
                  </div>
                </div>
              ) : (
                <div className="space-y-3">
                  <Upload className="h-12 w-12 mx-auto text-muted-foreground" />
                  <div>
                    <p className="text-sm font-medium">
                      Drop your ID document here, or{" "}
                      <label
                        htmlFor="id-document-input"
                        className="text-primary hover:underline cursor-pointer"
                      >
                        browse
                      </label>
                    </p>
                    <p className="text-xs text-muted-foreground mt-1">
                      Supports JPG, PNG, PDF (max 5MB)
                    </p>
                  </div>
                </div>
              )}
            </div>
          </div>

          {idVerificationStatus === "rejected" && (
            <div className="flex items-start gap-2 rounded-lg border border-amber-200 bg-amber-50 p-3">
              <AlertCircle className="h-5 w-5 text-amber-600 flex-shrink-0 mt-0.5" />
              <p className="text-sm text-amber-900">
                Please upload a new document addressing the rejection reason above.
              </p>
            </div>
          )}
        </>
      )}
    </div>
  );
}
