import { expect } from "chai";

export const expectThrow = async (p: Promise<any>, message: string) => {
  let threw: unknown = null;
  try {
    await p;
  } catch(e) {
    threw = e;
  }
  expect(threw, message).to.not.be.null;
}

export const expectNoThrow = async (p: Promise<any>, message: string) => {
  let threw: unknown = null;
  try {
    await p;
  } catch(e) {
    console.error(e);
    threw = e;
  }
  expect(threw, message).to.be.null;
}