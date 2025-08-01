// assets/js/ssr.tsx
import axios from "axios";
import React from "react";
import ReactDOMServer from "react-dom/server";
import { createInertiaApp } from "@inertiajs/react";
import Layout from "./components/layouts/layout";
import { AuthProvider } from "./contexts/auth-context";

axios.defaults.xsrfHeaderName = "x-csrf-token";

export function render(page) {
  console.log("SSR rendering page:", page);
  return createInertiaApp({
    page,
    render: ReactDOMServer.renderToString,
    resolve: async (name) => {
      const page = await import(`./pages/${name}.tsx`);
      page.default.layout =
        page.default.layout ||
        ((page: React.ReactNode) => (
          <AuthProvider>
            <Layout>{page}</Layout>
          </AuthProvider>
        ));
      return page;
    },
    setup: ({ App, props }) => <App {...props} />,
  });
}
