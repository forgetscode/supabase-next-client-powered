import Head from 'next/head';
import Loading from '#/components/loading';
import { ProfileForm } from '#/components/profile-form';
import { useUserProfile } from "#/hooks/with-react-context/use-profile";

export default function ProfilePage() {

  const { fetching: loadingProfile } = useUserProfile();
  if (loadingProfile) {
    return (
      <Loading/>
    );
  }
  return (
    <>
      <Head>
        <title>SupaBase</title>
        <link rel='icon' href="https://raw.githubusercontent.com/praveenpuglia/tailwind-breeze/master/assets/logo.svg" />
      </Head>
      <ProfileForm  />
    </>
  );
}
