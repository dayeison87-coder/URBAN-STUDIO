import { GoogleGenAI } from "@google/genai";
import dotenv from "dotenv";

dotenv.config();

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
});

async function main() {
  try {
    const response = await ai.models.generateContent({
      model: "gemini-flash-latest",
      contents: "Responde únicamente: OK"
    });

    console.log(response.text);
  } catch (e) {
    console.error(e);
  }
}

main();