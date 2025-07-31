import axios from "axios";

import { createInertiaApp } from "@inertiajs/react";
import { createRoot } from "react-dom/client";
import Layout from "./components/layouts/layout";
import { AuthProvider } from "./contexts/auth-context";

axios.defaults.xsrfHeaderName = "x-csrf-token";

createInertiaApp({
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
  setup({ App, el, props }) {
    createRoot(el).render(<App {...props} />);
  },
});
