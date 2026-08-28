import { GoogleGenAI } from "@google/genai";
import dotenv from "dotenv";
import fs from "fs";

dotenv.config();

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
});

async function analizarRostro() {
  try {
    const imagePath = "./1.jpg";

    if (!fs.existsSync(imagePath)) {
      console.error("❌ No se encontró la imagen:", imagePath);
      return;
    }

    const imageBuffer = fs.readFileSync(imagePath);
    const base64Image = imageBuffer.toString("base64");

    console.log("✅ Imagen encontrada");
    console.log("📷 Tamaño:", imageBuffer.length, "bytes");

    const prompt = `
Eres un barbero profesional y experto en visagismo.

Analiza la fotografía de la persona y responde ÚNICAMENTE un JSON válido, sin texto adicional.

{
  "forma_rostro": "",
  "tipo_craneo": "",
  "tipo_cabello": "",
  "corte_recomendado": "",
  "razon": ""
}
`;

    console.log("🤖 Analizando rostro...");

    const response = await ai.models.generateContent({
      model: "gemini-flash-latest",
      contents: [
        {
          inlineData: {
            mimeType: "image/jpeg",
            data: base64Image,
          },
        },
        {
          text: prompt,
        },
      ],
    });

    console.log("\n===== RESPUESTA =====\n");
    console.log(response.text);

    try {
      const json = JSON.parse(response.text);

      console.log("\n===== JSON =====");
      console.log(json);
    } catch {
      console.log("\nLa IA respondió texto en lugar de JSON puro.");
    }
  } catch (error) {
    console.error("\n❌ Error:");
    console.error(error);
  }
}

analizarRostro();