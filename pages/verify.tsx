import { JSXComponent, useEffect } from "react";
import { useRouter } from "next/router";
import { useSession } from "@supabase/auth-helpers-react";


const Verify: JSXComponent = () => {
  const router = useRouter();
  const session = useSession();
  useEffect(() => {
    console.log({ router, session });
    // (async () => {
    //   const { error } = await supabase.auth.signInWithOtp({
    //     email,
    //     options: {
    //       emailRedirectTo: `${serverURI}/verify`
    //     }
    //   });
    // })();
  }, [ router, session ]);
  return (
    <div>verify</div>
  );
};

export default Verify;
