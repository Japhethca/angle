import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { LocationCombobox } from "./location-combobox";
import * as ashQuery from "@/hooks/use-ash-query";

// Mock useAshQuery
vi.mock("@/hooks/use-ash-query");

const mockLocationData = {
  id: "test-id",
  name: "Nigerian States",
  slug: "ng-states",
  optionSetValues: [
    { id: "1", value: "Lagos", label: "Lagos", parentValue: null },
    { id: "2", value: "Abia", label: "Abia", parentValue: null },
    { id: "3", value: "Kano", label: "Kano", parentValue: null },
  ],
  children: [
    {
      id: "child-1",
      name: "Lagos LGAs",
      optionSetValues: [
        { id: "4", value: "Ikeja", label: "Ikeja", parentValue: "Lagos" },
        { id: "5", value: "Surulere", label: "Surulere", parentValue: "Lagos" },
      ],
    },
    {
      id: "child-2",
      name: "Abia LGAs",
      optionSetValues: [
        { id: "6", value: "Aba North", label: "Aba North", parentValue: "Abia" },
        { id: "7", value: "Aba South", label: "Aba South", parentValue: "Abia" },
      ],
    },
  ],
};

describe("LocationCombobox", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("loads and displays location data", async () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    // Should show combobox button
    expect(screen.getByRole("combobox")).toBeInTheDocument();
    expect(screen.getByText("Select location...")).toBeInTheDocument();
  });

  it("opens dialog and shows all options when clicked", async () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    const user = userEvent.setup();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    const button = screen.getByRole("combobox");
    await user.click(button);

    // Dialog should open with all options
    await waitFor(() => {
      expect(screen.getByText("Select Location")).toBeInTheDocument();
      expect(screen.getByText("Lagos")).toBeInTheDocument();
      expect(screen.getByText("Abia")).toBeInTheDocument();
      expect(screen.getByText("Ikeja")).toBeInTheDocument();
      expect(screen.getByText("Surulere")).toBeInTheDocument();
    });
  });

  it("filters options based on search query", async () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    const user = userEvent.setup();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    // Open dialog
    await user.click(screen.getByRole("combobox"));

    // Wait for dialog to open
    await waitFor(() => {
      expect(screen.getByPlaceholderText("Search state or LGA")).toBeInTheDocument();
    });

    // Type in search box
    const searchInput = screen.getByPlaceholderText("Search state or LGA");
    await user.type(searchInput, "ikeja");

    // Should show filtered results
    await waitFor(() => {
      expect(screen.getByText("Ikeja")).toBeInTheDocument();
      expect(screen.queryByText("Kano")).not.toBeInTheDocument();
    });
  });

  it("handles state-only selection", async () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    const user = userEvent.setup();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    // Open dialog
    await user.click(screen.getByRole("combobox"));

    // Wait for dialog and click Lagos state
    await waitFor(() => {
      expect(screen.getByText("Lagos")).toBeInTheDocument();
    });

    // Find the Lagos button (which is a state, not an LGA)
    const lagosButtons = screen.getAllByText("Lagos");
    const lagosStateButton = lagosButtons.find(
      (el) => el.classList.contains("font-medium")
    );

    if (lagosStateButton) {
      await user.click(lagosStateButton);
    }

    expect(onChange).toHaveBeenCalledWith({ state: "Lagos" });
  });

  it("handles state+LGA selection", async () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    const user = userEvent.setup();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    // Open dialog
    await user.click(screen.getByRole("combobox"));

    await waitFor(() => {
      expect(screen.getByText("Ikeja")).toBeInTheDocument();
    });

    // Click on Ikeja LGA
    await user.click(screen.getByText("Ikeja"));

    expect(onChange).toHaveBeenCalledWith({ state: "Lagos", lga: "Ikeja" });
  });

  it("displays loading state while fetching", () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: null,
      isLoading: true,
      error: null,
    } as any);

    const onChange = vi.fn();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    expect(screen.getByText(/loading locations/i)).toBeInTheDocument();
  });

  it("displays selected state value", () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    render(
      <LocationCombobox
        value={{ state: "Lagos" }}
        onChange={onChange}
      />
    );

    expect(screen.getByText("Lagos")).toBeInTheDocument();
  });

  it("displays selected state + LGA value", () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    render(
      <LocationCombobox
        value={{ state: "Lagos", lga: "Ikeja" }}
        onChange={onChange}
      />
    );

    expect(screen.getByText("Lagos → Ikeja")).toBeInTheDocument();
  });

  it("displays error message when provided", () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    render(
      <LocationCombobox
        value={undefined}
        onChange={onChange}
        error="Location is required"
      />
    );

    expect(screen.getByText("Location is required")).toBeInTheDocument();
  });

  it("shows empty state when no results found", async () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    const user = userEvent.setup();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    // Open dialog
    await user.click(screen.getByRole("combobox"));

    await waitFor(() => {
      expect(screen.getByPlaceholderText("Search state or LGA")).toBeInTheDocument();
    });

    // Search for non-existent location
    const searchInput = screen.getByPlaceholderText("Search state or LGA");
    await user.type(searchInput, "nonexistent");

    await waitFor(() => {
      expect(screen.getByText("No location found")).toBeInTheDocument();
    });
  });
});
