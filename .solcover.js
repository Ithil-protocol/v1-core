const shell = require("shelljs");

module.exports = {
  istanbulReporter: ["text"],
  configureYulOptimizer: true,
  providerOptions: {
    privateKey: process.env.PRIVATE_KEY,
  },
  skipFiles: ["test", "mock", "interfaces"],
};
