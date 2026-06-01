
    export { default } from "../../build/server/server.js";

    export const config = {
      name: "Remix server handler",
      generator: "@netlify/remix-adapter@3.0.0",
      path: "/*",
      preferStatic: true,
    };
    