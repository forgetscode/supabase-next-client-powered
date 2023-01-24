import { useSession } from "@supabase/auth-helpers-react";
import { Auth, ThemeSupa } from "@supabase/auth-ui-react";
import React, { FCWithChildren } from "react";
import { useSupabase } from "#/hooks/useSupabase";

/** @desc This is a temporary component for forcing supabase login before child components are rendered. */
export const SupabaseAuth: FCWithChildren = ({ children }) => {
  const session = useSession();
  const supabase = useSupabase();
  if (session) {
    return <>{children}</>;
  }
  return (
    <div className="w-1/2 mx-auto">
      <Auth
        magicLink
        supabaseClient={supabase}
        appearance={{ theme: ThemeSupa }}
        theme="dark"
        providers={[ "apple", "google" ]}
      />
    </div>
  );
};


