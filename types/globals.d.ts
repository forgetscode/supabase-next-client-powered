/// <reference path="react-extensions" />
/** GENERAL TYPES */

/** @desc Same as built-in typescript type "Record<K, V>", except the values are readonly. */
type ReadonlyRecord<K extends string | number , V extends any, T extends object = Record<K, V>> =  { readonly [K in keyof T]: T[K]  };

/** @desc removes null from all properties of object given by "T" in the case that true is passed to "C" */
type ExcludeTypeFromProps<
  T extends object,
  E extends T[keyof T],
  C extends boolean
> = C extends false ? T : {
  [K in keyof T]: Exclude<T[K], E>
};
