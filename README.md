### Notes:
- `component/supabase-auth.tsx` is currently being used in `_app.tsx` in a way that if the user is not logged in, none of the pages or children components will render. This is a placeholder that will probably be changed.
- `#/` at the start of an import statements means relative to the root of the project. In other words, `import "#/thing"` syntax means "import the folder thing from the root".
- `hooks/with-react-context/example-hook-with-context.tsx` was created to give an example of creating a provider component for providing React Context, and a hook which consumes it.
- 
