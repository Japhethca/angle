import { Plus, X } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";

interface FeatureFieldsProps {
  features: string[];
  onChange: (features: string[]) => void;
}

export function FeatureFields({ features, onChange }: FeatureFieldsProps) {
  const addFeature = () => {
    onChange([...features, ""]);
  };

  const removeFeature = (index: number) => {
    onChange(features.filter((_, i) => i !== index));
  };

  const updateFeature = (index: number, value: string) => {
    const updated = [...features];
    updated[index] = value;
    onChange(updated);
  };

  return (
    <div className="space-y-3">
      <Label className="text-sm font-medium">Features</Label>
      {features.map((feature, index) => (
        <div key={index} className="flex items-center gap-2">
          <Input
            placeholder={`Feature ${index + 1}`}
            value={feature}
            onChange={(e) => updateFeature(index, e.target.value)}
          />
          <button
            type="button"
            onClick={() => removeFeature(index)}
            className="shrink-0 text-content-tertiary hover:text-feedback-error"
          >
            <X className="size-4" />
          </button>
        </div>
      ))}
      <Button
        type="button"
        variant="outline"
        size="sm"
        onClick={addFeature}
        className="gap-1.5"
      >
        <Plus className="size-3.5" />
        Add Feature
      </Button>
    </div>
  );
}
