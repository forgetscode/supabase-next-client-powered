import { createContext, FCWithChildren, useContext, useEffect, useState } from "react";
import { sleep } from "#/utils/general";

interface ExampleHookContext {
  loading: boolean
}

const ExampleHookContext = createContext<ExampleHookContext>({
  loading: false
});

export const ExampleHookContextProvider: FCWithChildren = ({ children }) => {
  const [ loading, setLoading ] = useState(false);

  useEffect(() => {
    setLoading(true);
    sleep(1000)
      .then(() => setLoading(false));
  }, []);

  return (
    <ExampleHookContext.Provider value={{
      loading: loading
    }}>
      {children}
    </ExampleHookContext.Provider>
  );
};

export const useExampleHook = () => {
  return useContext(ExampleHookContext);
};


