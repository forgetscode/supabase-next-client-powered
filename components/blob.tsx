
// TODO: what the hell does this even do??

export const Blob = () => (
  <>
    <div className='
            absolute top-0 -left-4 w-[540px] h-full max-h-[540px] filter blur-xl opacity-50 mix-blend-multiply bg-teal-500 rounded-full -z-10 animate-blob'
    />
    <div className='
            absolute top-0 w-[540px] h-full max-h-[540px]  filter blur-xl opacity-50 mix-blend-multiply bg-blue-400 rounded-full -z-10 animate-blob'
    />
    <div className='
            absolute top-0 -right-4 w-[540px] max-h-[540px]  h-full filter blur-xl  opacity-50 mix-blend-multiply bg-sky-500 rounded-full -z-10 animate-blob animation-delay-2000'
    />
    <div className='
            absolute -bottom-8 left-20 w-[540px] max-h-[540px] h-full filter blur-xl opacity-50 first-line:mix-blend-multiply bg-indigo-500 rounded-full -z-10 animate-blob animation-delay-4000'
    />
  </>
);
