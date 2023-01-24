
import Router, { useRouter } from 'next/router';
import { useState, useEffect, JSXComponent, useCallback } from 'react';
import { EditAvatar } from './edit-avatar';
import { Blob } from './blob';
import { useSession, useUser } from "@supabase/auth-helpers-react";
import { useSupabase } from "#/hooks/useSupabase";
import { TableInsert } from '#/types/supabase';
import { useUserProfile } from "#/hooks/with-react-context/use-profile";
const Fade = require("react-reveal/Fade");

export const ProfileForm: JSXComponent = () => {
  const [ updating, setUpdating ] = useState(false);
  const [ name, setName ] = useState<string>();
  const router = useRouter();
  // const [ website, setWebsite ] = useState<string>('');
  const [ avatar, setAvatar ] = useState<string>();
  const { fetching: loadingProfile, error, profile } = useUserProfile();
  const user = useUser();
  const supabase = useSupabase();
  const session = useSession();
  useEffect(() => {
    console.log({ session });
  }, [ session ]);
  useEffect(() => {
    if (profile) {
      setName(profile.name);
      // setWebsite(profile.website);
      setAvatar(profile.avatar);
    }
  }, [ profile ]);

  const updateProfile = useCallback(async (updatedProfile: TableInsert<"profiles">) => {
    try {
      setUpdating(true);
      const { error } = await supabase.from('profiles')
        .upsert(updatedProfile);

      if (error) {
        console.log(error);
        throw error;
      }
    } catch (error: any) {
      alert(error.message);
    } finally {
      setUpdating(false);
    }
  }, [ supabase ]);

  if (loadingProfile) {
    return <p>Loading…</p>;
  }

  if (error) {
    return <p>An error occurred when fetching your profile information.</p>;
  }

  return (
    <Fade>
      <div className='flex h-full w-full justify-center items-center'>
        <div className='max-w-[540px] md:w-[540px] bg-gray-900 relative flex flex-col space-y-8 p-12 rounded-lg px-16 border border-teal-400 shadow-lg shadow-teal-600'>
          <Blob/>
          <p className="text-3xl font-black text-white">Profile</p>
          <form className="flex flex-col space-y-8">
            <div className="form-group">
              <div className="pb-8">
                <EditAvatar url={avatar} onUpload={(url) => setAvatar(url)} />
              </div>
              <label className="label text-white" htmlFor="email">
                Email
              </label>
              <input
                id="email"
                type="text"
                value={user?.email ?? ""}
                disabled
              />
            </div>
            <div className="form-group">
              <label className="label text-white" htmlFor="name">
                Name
              </label>
              <input
                disabled={updating}
                id="name"
                type="text"
                value={name ?? ""}
                onChange={(e) => setName(e.target.value)}
              />
            </div>
            {/*<div className="form-group">*/}
            {/*  <label className="label text-white" htmlFor="website">*/}
            {/*    Website*/}
            {/*  </label>*/}
            {/*  <input*/}
            {/*    disabled={updating}*/}
            {/*    id="website"*/}
            {/*    type="website"*/}
            {/*    value={website}*/}
            {/*    onChange={(e) => setWebsite(e.target.value)}*/}
            {/*  />*/}
            {/*</div>*/}
            <div>
              <button
                onClick={() => user?.id && updateProfile({ name, avatar, id: user.id })}
                disabled={updating || !user?.id}
              >
                {updating ? 'Updating…' : 'Update'}
              </button>
            </div>
            <button
              onClick={async (event) => {
                event.preventDefault();
                event.stopPropagation();
                await supabase.auth.signOut();
                await router.push('/');
              }}
            >
                Sign out
            </button>
          </form>
        </div>
      </div>
    </Fade>
  );
};
