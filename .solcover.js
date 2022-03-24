const shell = require("shelljs");

module.exports = {
  istanbulReporter: ["text"],
  providerOptions: {
    privateKey: process.env.PRIVATE_KEY,
  },
  skipFiles: ["test", "mock"],
};
