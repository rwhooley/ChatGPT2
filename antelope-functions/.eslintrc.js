module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  parser: "@babel/eslint-parser",
  parserOptions: {
    ecmaVersion: 2018,
    sourceType: "module",
  },
  rules: {
    quotes: ["error", "double"],
    "max-len": ["error", {code: 100}],
    "object-curly-spacing": ["error", "never"],
    indent: ["error", 2],
  },
};
