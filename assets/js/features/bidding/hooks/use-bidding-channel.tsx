import { useState, useCallback } from 'react'
import { usePhoenixChannel } from './use-phoenix-channel'

interface Bid {
  id: string
  amount: number
  bidder_id: string
  item_id: string
  inserted_at: string
}

interface Item {
  id: string
  title: string
  current_bid?: Bid
  bid_count: number
  status: string
}

interface UseBiddingChannelOptions {
  itemId?: string
  userId?: string
}

export function useBiddingChannel({ itemId, userId }: UseBiddingChannelOptions = {}) {
  const [bids, setBids] = useState<Bid[]>([])
  const [currentItem, setCurrentItem] = useState<Item | null>(null)
  const [isPlacingBid, setIsPlacingBid] = useState(false)

  const { isConnected, send, on } = usePhoenixChannel({
    topic: itemId ? `item:${itemId}` : 'bidding:lobby',
    params: { user_id: userId },
    onError: (error) => {
      console.error('Failed to connect to bidding channel:', error)
    }
  })

  // Listen for new bids
  on('new_bid', useCallback((payload: { bid: Bid, item: Item }) => {
    setBids(prevBids => [payload.bid, ...prevBids])
    setCurrentItem(payload.item)
  }, []))

  // Listen for bid updates (outbid, winner, etc.)
  on('bid_update', useCallback((payload: { bid: Bid, status: string }) => {
    setBids(prevBids => 
      prevBids.map(bid => 
        bid.id === payload.bid.id 
          ? { ...bid, ...payload.bid }
          : bid
      )
    )
  }, []))

  // Listen for item status changes
  on('item_status_changed', useCallback((payload: { item: Item }) => {
    setCurrentItem(payload.item)
  }, []))

  // Listen for auction end
  on('auction_ended', useCallback((payload: { item: Item, winning_bid?: Bid }) => {
    setCurrentItem(payload.item)
    // Could trigger notifications here
  }, []))

  const placeBid = useCallback(async (amount: number) => {
    if (!itemId || !isConnected) return

    setIsPlacingBid(true)
    
    send('place_bid', { 
      item_id: itemId, 
      amount: amount 
    })

    // Reset loading state after a timeout
    // In real implementation, you'd listen for success/error responses
    setTimeout(() => setIsPlacingBid(false), 1000)
  }, [itemId, isConnected, send])

  const joinItemChannel = useCallback((newItemId: string) => {
    send('join_item', { item_id: newItemId })
  }, [send])

  const leaveItemChannel = useCallback((oldItemId: string) => {
    send('leave_item', { item_id: oldItemId })
  }, [send])

  return {
    bids,
    currentItem,
    isConnected,
    isPlacingBid,
    placeBid,
    joinItemChannel,
    leaveItemChannel
  }
}