/**
 * TanStack Query wrapper hooks for AshTypescript RPC functions.
 *
 * These hooks combine TanStack Query's async state management (loading, error,
 * caching, refetching) with AshTypescript's generated typed RPC functions.
 *
 * PATTERN:
 *   1. Import the generated RPC function from ash_rpc.ts
 *   2. Wrap it with useAshQuery (for reads) or useAshMutation (for writes)
 *   3. Get typed data back with loading/error states for free
 *
 * EXAMPLE - Reading data:
 *
 *   import { listItems } from "@/ash_rpc";
 *   import { useAshQuery } from "@/hooks/use-ash-query";
 *
 *   function ItemList() {
 *     const { data, isLoading, error } = useAshQuery(
 *       ["items"],
 *       () => listItems({
 *         fields: ["id", "title", "startingPrice"],
 *         headers: buildCSRFHeaders(),
 *       })
 *     );
 *
 *     if (isLoading) return <div>Loading...</div>;
 *     if (error) return <div>Error: {error.message}</div>;
 *     if (!data) return <div>No items found</div>;
 *
 *     return (
 *       <ul>
 *         {data.map(item => (
 *           <li key={item.id}>{item.title} - {item.startingPrice}</li>
 *         ))}
 *       </ul>
 *     );
 *   }
 *
 * EXAMPLE - Mutating data:
 *
 *   import { makeBid, buildCSRFHeaders } from "@/ash_rpc";
 *   import { useAshMutation } from "@/hooks/use-ash-query";
 *
 *   function BidForm({ itemId }: { itemId: string }) {
 *     const { mutate, isPending, error } = useAshMutation(
 *       (amount: string) => makeBid({
 *         input: { amount, bidType: "manual", itemId },
 *         fields: ["id", "amount"],
 *         headers: buildCSRFHeaders(),
 *       }),
 *       { invalidateKeys: [["items"], ["bids"]] }
 *     );
 *
 *     return (
 *       <button onClick={() => mutate("100.00")} disabled={isPending}>
 *         {isPending ? "Placing bid..." : "Place Bid"}
 *       </button>
 *     );
 *   }
 */

import {
  useQuery,
  useMutation,
  useQueryClient,
  type UseQueryOptions,
  type UseMutationOptions,
  type QueryKey,
} from "@tanstack/react-query";

import type { AshRpcError } from "@/ash_rpc";

/**
 * Error class for failed AshTypescript RPC calls.
 * Wraps the structured error array from the RPC response.
 */
export class AshRpcRequestError extends Error {
  public readonly errors: AshRpcError[];

  constructor(errors: AshRpcError[]) {
    const message = errors.map((e) => e.message).join("; ") || "RPC request failed";
    super(message);
    this.name = "AshRpcRequestError";
    this.errors = errors;
  }
}

/**
 * The shape of a successful RPC response.
 * All AshTypescript RPC functions return { success: true, data: T } on success.
 */
type AshRpcSuccess<T> = { success: true; data: T };

/**
 * The shape of a failed RPC response.
 */
type AshRpcFailure = { success: false; errors: AshRpcError[] };

/**
 * Union of success/failure RPC responses.
 */
type AshRpcResult<T> = AshRpcSuccess<T> | AshRpcFailure;

/**
 * Unwraps an AshTypescript RPC result, throwing on failure.
 * This bridges the { success, data, errors } pattern into
 * TanStack Query's throw-on-error convention.
 */
function unwrapRpcResult<T>(result: AshRpcResult<T>): T {
  if (!result.success) {
    throw new AshRpcRequestError(result.errors);
  }
  return result.data;
}

/**
 * useAshQuery - Wraps a read RPC function with TanStack Query.
 *
 * Automatically unwraps the { success, data, errors } envelope from
 * AshTypescript RPC calls into TanStack Query's expected pattern:
 * - On success: returns the data directly
 * - On failure: throws AshRpcRequestError (caught by TanStack Query as `error`)
 *
 * @param queryKey - TanStack Query cache key (e.g., ["items"], ["bids", itemId])
 * @param queryFn - An AshTypescript RPC function call that returns a result envelope
 * @param options - Additional TanStack Query options (staleTime, enabled, etc.)
 *
 * @example
 * const { data, isLoading } = useAshQuery(
 *   ["categories"],
 *   () => listCategories({
 *     fields: ["id", "name"],
 *     headers: buildCSRFHeaders(),
 *   })
 * );
 */
export function useAshQuery<TData>(
  queryKey: QueryKey,
  queryFn: () => Promise<AshRpcResult<TData>>,
  options?: Omit<UseQueryOptions<TData, AshRpcRequestError>, "queryKey" | "queryFn">
) {
  return useQuery<TData, AshRpcRequestError>({
    queryKey,
    queryFn: async () => {
      const result = await queryFn();
      return unwrapRpcResult(result);
    },
    ...options,
  });
}

/**
 * useAshMutation - Wraps a mutation RPC function with TanStack Query.
 *
 * Handles the AshTypescript result envelope and optionally invalidates
 * related query caches after a successful mutation.
 *
 * @param mutationFn - A function that takes input and calls an AshTypescript RPC mutation
 * @param options - Configuration including invalidateKeys and standard TanStack mutation options
 *
 * @example
 * const { mutate, isPending } = useAshMutation(
 *   (input: CreateDraftItemInput) => createDraftItem({
 *     input,
 *     fields: ["id", "title"],
 *     headers: buildCSRFHeaders(),
 *   }),
 *   { invalidateKeys: [["items"]] }
 * );
 */
export function useAshMutation<TInput, TData>(
  mutationFn: (input: TInput) => Promise<AshRpcResult<TData>>,
  options?: Omit<UseMutationOptions<TData, AshRpcRequestError, TInput>, "mutationFn"> & {
    /** Query keys to invalidate after a successful mutation */
    invalidateKeys?: QueryKey[];
  }
) {
  const queryClient = useQueryClient();
  const { invalidateKeys, onSuccess, ...restOptions } = options ?? {};

  return useMutation<TData, AshRpcRequestError, TInput>({
    mutationFn: async (input: TInput) => {
      const result = await mutationFn(input);
      return unwrapRpcResult(result);
    },
    onSuccess: (data, variables, context) => {
      // Invalidate specified query caches
      if (invalidateKeys) {
        for (const key of invalidateKeys) {
          queryClient.invalidateQueries({ queryKey: key });
        }
      }
      // Call user's onSuccess if provided
      onSuccess?.(data, variables, context);
    },
    ...restOptions,
  });
}
