import { useEffect, useRef } from "react";

/**
 * Subscribe to a CustomEvent dispatched on `document` by the Python backend
 * (window.invoke → CustomEvent bridge). Handles the EventListener cast and
 * add/remove pairing in one place.
 *
 * The handler is held in a ref, so callers can pass inline closures without
 * re-subscribing on every render — the subscription only resets if the event
 * name changes.
 */
export function useBackendEvent<T>(name: string, handler: (detail: T) => void) {
  const handlerRef = useRef(handler);
  handlerRef.current = handler;

  useEffect(() => {
    const listener = (event: Event) => {
      if (!(event instanceof CustomEvent)) return;
      handlerRef.current(event.detail as T);
    };
    document.addEventListener(name, listener);
    return () => document.removeEventListener(name, listener);
  }, [name]);
}
