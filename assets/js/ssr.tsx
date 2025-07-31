// assets/js/ssr.tsx
import axios from "axios";
import React from "react";
import ReactDOMServer from "react-dom/server";
import { createInertiaApp } from "@inertiajs/react";

axios.defaults.xsrfHeaderName = "x-csrf-token";

export function render(page) {
  return createInertiaApp({
    page,
    render: ReactDOMServer.renderToString,
    resolve: async (name) => {
      return await import(`./pages/${name}.tsx`);
    },
    setup: ({ App, props }) => <App {...props} />,
  });
}
