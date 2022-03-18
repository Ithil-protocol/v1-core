const shell = require("shelljs");

module.exports = {
  istanbulReporter: ["text"],
  providerOptions: {
    mnemonic: process.env.MNEMONIC,
  },
  skipFiles: ["test", "mock"],
};
