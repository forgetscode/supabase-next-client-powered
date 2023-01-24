import { Dispatch, FC, ReactElement, ReactFragment, ReactPortal, SetStateAction } from "react";

declare module "react" {
  import type { Dispatch, FC, ReactElement, ReactFragment, ReactPortal, SetStateAction } from "react";
  type ReactComponentReturn =
    ReactElement
    | ReactFragment
    | ReactPortal
    | null;

  type ReactJSX = ReactComponentReturn | boolean | string | number | undefined;

  type WithChildren<T = {}> = {
    children: ReactJSX
  } & T;

  type JSXComponent<T = {}> = (props: T) => ReactElement;

  type JSXWithChildren<T = {}> = JSXComponent<WithChildren<T>>;
  type FCWithChildren<T = {}> = FC<WithChildren<T>>;
  type TSetState<T> = Dispatch<SetStateAction<T>>;
}
