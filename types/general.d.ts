

export declare type ReadonlyRecord<K extends string | number , V extends any, T extends object = Record<K, V>> =  { readonly [K in keyof T]: T[K]  };





