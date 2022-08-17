import { expect } from "chai";

export const expectThrow = async (p: Promise<any>, message: string) => {
  let threw = false;
  try {
    await p;
  } catch {
    threw = true;
  }
  expect(threw, message).to.be.true;
}

export const expectNoThrow = async (p: Promise<any>, message: string) => {
  let threw = false;
  try {
    await p;
  } catch {
    threw = true;
  }
  expect(threw, message).to.be.false;
}