import { AuthSession } from '@supabase/supabase-js';
import Head from 'next/head';
import Link from 'next/link';
import React, { FCWithChildren } from 'react';
import Image from "next/image";
import { icon, title } from "#/constants/meta";

export const Layout: FCWithChildren = ({ children }) => (
  <>
    <Head>
      <title>{title}</title>
      <link rel='icon' href={icon} />
    </Head>
    <div className="flex flex-col h-screen bg-black overflow-x-hidden">
      <header className="p-4  justify-between items-center bg-zinc-900 h-28 z-20 hidden xl:flex">
        <h1 className='flex flex-row justify-end space-x-4'>
          {/*<Image height={12} width={12} className="h-12 w-12" src="https://raw.githubusercontent.com/praveenpuglia/tailwind-breeze/master/assets/logo.svg" alt="My Image"/>*/}
          <Link href="/">
            <p className=" text-3xl font-black text-white">
              Client Powered
            </p>
          </Link>
        </h1>
      </header>
      <main className="flex-1 p-6">{ children }</main>
      <footer className="bg-zinc-900 text-gray-600 p-4 font-light text-xs h-12 z-20 hidden xl:flex">
        2023 Demo
      </footer>
    </div>
  </>
);
