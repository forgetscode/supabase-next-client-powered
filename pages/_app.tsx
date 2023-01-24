import "#/_external/process-getter";
import '#/styles/globals.css';
import { AppProps } from 'next/app';
import { SessionContextProvider } from "@supabase/auth-helpers-react";
import { HookProviders } from "#/hooks/with-react-context";
import { Layout } from "#/components/layout";
import { createSupabaseBrowserClient } from "#/lib/supabase-clients";

const supabase = createSupabaseBrowserClient();
const _App = ({ Component, pageProps }: AppProps) => (
  <SessionContextProvider supabaseClient={ supabase } initialSession={ pageProps.initialSession }>
    {/*<SupabaseAuth>*/}
    <HookProviders>
      <Layout>
        <Component { ...pageProps } />
      </Layout>
    </HookProviders>
    {/*</SupabaseAuth>*/}
  </SessionContextProvider>
);

export default _App;
