
const devURI = "http://localhost:3000";
const prodURI = "";
export const isProduction = process.env.NODE_ENV === "production";
export const serverURI = isProduction ? prodURI : devURI;


