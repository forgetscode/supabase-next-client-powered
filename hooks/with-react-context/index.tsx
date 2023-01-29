import { FCWithChildren } from "react";
//import { ExampleHookContextProvider } from "#/hooks/with-react-context/example-hook-with-context";
import { UserProfileContextProvider } from "#/hooks/with-react-context/use-profile";
import { isProduction } from "#/constants/environment";

/** index of folder with files and folders containing modules which export React hooks which access React context */

const hookProviders = {
  //ExampleHookContextProvider,
  UserProfileContextProvider
};

if (isProduction && (hookProviders as any).ExampleHookContextProvider != null) {
  throw new Error(`ExampleHookContextProvider is still added as provider in production!`);
}

/** @desc reduces all provider components into one component by wrapping children with them hierarchically in reverse order of
 *  the above object. this means that providers which are higher up in the object will be higher in the component
 *  stack, which can be important if some providers need to use hooks from others to function.
 *
 *  with just "UserContextProvider" and "GoogleMapsRequestProvider", it would be equivalent to:
 *  return (
 *    <UserContextProvider>
 *      <GoogleMapsRequestProvider>
 *        {children}
 *      </GoogleMapsRequestProvider>
 *    </UserContextProvider
 *  );
 *  */
export const HookProviders: FCWithChildren = ({ children }) => (
  <>
    {Object.entries(hookProviders)
      .reverse()
      .reduce((obj, [ name, HookProvider ]) => (
        <HookProvider key={name}>{obj}</HookProvider>
      ), children)}
  </>
);
