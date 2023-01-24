import Head from 'next/head';
// import  Router  from 'next/router';
import { useEffect, useState } from 'react';
import Loading from '#/components/loading';
import { SignInForm } from '#/components/sign-in-form';
import { useSession } from "@supabase/auth-helpers-react";
import { useRouter } from "next/router";

export default function Home() {
  const session = useSession();
  const [ loading, setLoading ] = useState(true);
  const router = useRouter();
  useEffect(() => {
    setTimeout(() => {
      setLoading(false);
    }, 1000);
  }, []);

  useEffect(() => {
    console.log({ session });
    if (session) {
      router.push('/profile').catch(console.error);
    }
  }, [ router, session ]);

  if (loading) {
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
      <SignInForm />
    </>
  );
}
