
/** Checks that process.env values are not undefined when they are attempted to be accessed by replacing all
 *   properties with getters to remove typescript boilerplate for checking for this elsewhere.
 *  (This should probably be an npm package at some point) */

let oldProcessEnv = { ...process.env };

let newProcessEnv: typeof process.env = {
  get NODE_ENV() {
    return process.env.NODE_ENV;
  }
};
for (const envKey in process.env) {
  if (oldProcessEnv.hasOwnProperty(envKey) && envKey !== "NODE_ENV") {
    Object.defineProperty(newProcessEnv, envKey, {
      get: function(): string {
        const envValue = oldProcessEnv[envKey];
        if (envValue === undefined) {
          throw new Error(`could not get process.env.${envKey}!`);
        }
        return envValue;
      }
    });
  }
}

process.env = newProcessEnv;

export {};
