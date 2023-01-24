import { TableInsert, TableRow } from "#/types/supabase";
import { User, useUser } from "@supabase/auth-helpers-react";
import { createContext, FCWithChildren, useContext, useEffect, useMemo, useState } from "react";
import { useSupabase } from "#/hooks/use-supabase";

type PublicProfile = TableInsert<"profiles", true>;
type PrivateProfile = TableInsert<"profiles_private", true>;
interface UserProfileContext {
  error: any[] | null,
  fetching: boolean,
  profile: (PublicProfile & PrivateProfile) | null,
  auth: User | null
}

const UserProfileContext = createContext<UserProfileContext>({
  error: null,
  fetching: false,
  profile: null,
  auth: null
});

export const UserProfileContextProvider: FCWithChildren = ({ children }) => {
  const [ error, setError ] = useState<any[] | null>(null);
  const [ publicProfile, setPublicProfile ] = useState<PublicProfile | null >(null);
  const [ privateProfile, setPrivateProfile ] = useState<PrivateProfile | null>(null);
  const [ fetching, setFetching ] = useState(false);
  const user = useUser();
  const supabase = useSupabase();
  useEffect(() => {
    if (!user) {
      return;
    }
    setFetching(true);
    (async () => {
      supabase.from("profiles")
        .select()
        .eq("id", user.id)
        .single()
        .then(res => {
          if (res.error) {
            throw res;
          }
          return res.data;
        })
        .then(res =>
          setPublicProfile({
            id: res.id,
            name: res.name ?? undefined,
            avatar: res.avatar ?? undefined
          })
        );
      supabase.from("profiles_private")
        .select()
        .eq("id", user.id)
        .single()
        .then(res => {
          if (res.error) {
            throw res;
          }
          return res.data;
        })
        .then(res =>
          setPrivateProfile({
            id: res.id,
            admin: res.admin,
            email: res.email,
            phone: res.phone ?? undefined
          })
        );
    })()
      .catch(err => {
        console.error("error fetching profile", err);
        setError([ "error fetching profile", err ]);
      })
      .finally(() => {
        setFetching(false);
      });
  }, [ supabase, user ]);

  const profile = useMemo(() => {
    if (publicProfile && privateProfile) {
      return {
        ...publicProfile,
        ...privateProfile
      };
    }
    return null;
  }, [ publicProfile, privateProfile ]);

  return (
    <UserProfileContext.Provider value={{
      auth: user,
      profile: profile,
      fetching: fetching,
      error: error
    }}>
      {children}
    </UserProfileContext.Provider>
  );
};

export const useUserProfile = () => {
  return useContext(UserProfileContext);
};


