
type ReadonlyRecord<K extends string | number, V extends any, T extends object = Record<K, V>> =  { readonly [K in keyof T]: T[K]  };

declare namespace NodeJS {
  interface ProcessEnv extends ReadonlyRecord<string, string> {}
}
