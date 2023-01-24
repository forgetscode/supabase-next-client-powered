import React from "react";

const Loading = () => (
  <div className="flex items-center justify-center h-full w-full">
    <div className="flex flex-col space-y-4">
      <div className="border-t-transparent border-solid animate-spin rounded-full border-white border-4 h-8 w-8 md:h-12 md:w-12 mx-auto"></div>
      <p className="xl:text-3xl lg:text-2xl md:text-xl text-lg mx-auto text-white">Loading...</p>
    </div>
  </div>
);

export default Loading;
