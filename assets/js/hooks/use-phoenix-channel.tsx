import { useEffect, useRef, useState } from "react";
import { Socket, Channel } from "phoenix";

interface UsePhoenixChannelOptions {
  topic: string;
  params?: Record<string, any>;
  onJoin?: () => void;
  onError?: (error: any) => void;
  onClose?: () => void;
}

interface ChannelHook {
  channel: Channel | null;
  isConnected: boolean;
  send: (event: string, payload?: any) => void;
  on: (event: string, callback: (payload: any) => void) => () => void;
}

export function usePhoenixChannel({
  topic,
  params = {},
  onJoin,
  onError,
  onClose,
}: UsePhoenixChannelOptions): ChannelHook {
  const [isConnected, setIsConnected] = useState(false);
  const socketRef = useRef<Socket | null>(null);
  const channelRef = useRef<Channel | null>(null);
  const listenersRef = useRef<Map<string, number>>(new Map());

  useEffect(() => {
    // Initialize socket if not exists
    if (!socketRef.current) {
      socketRef.current = new Socket("/socket", {
        params: () => {
          // You can add auth tokens here if needed
          const token = document
            .querySelector('meta[name="csrf-token"]')
            ?.getAttribute("content");
          return { _csrf_token: token };
        },
      });
      socketRef.current.connect();
    }

    // Join channel
    const channel = socketRef.current.channel(topic, params);
    channelRef.current = channel;

    channel
      .join()
      .receive("ok", () => {
        setIsConnected(true);
        onJoin?.();
      })
      .receive("error", (error: Error) => {
        setIsConnected(false);
        onError?.(error);
      });

    channel.onClose(() => {
      setIsConnected(false);
      onClose?.();
    });

    return () => {
      // Clean up listeners
      listenersRef.current.forEach((ref, event) => {
        channel.off(event, ref);
      });
      listenersRef.current.clear();

      // Leave channel
      channel.leave();
      channelRef.current = null;
      setIsConnected(false);
    };
  }, [topic, JSON.stringify(params)]);

  const send = (event: string, payload: any = {}) => {
    if (channelRef.current && isConnected) {
      channelRef.current.push(event, payload);
    }
  };

  const on = (event: string, callback: (payload: any) => void) => {
    if (channelRef.current) {
      const ref = channelRef.current.on(event, callback);
      listenersRef.current.set(event, ref);

      // Return cleanup function
      return () => {
        if (channelRef.current) {
          channelRef.current.off(event, ref);
          listenersRef.current.delete(event);
        }
      };
    }
    return () => {};
  };

  return {
    channel: channelRef.current,
    isConnected,
    send,
    on,
  };
}
