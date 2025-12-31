export default {
  async fetch(request, env) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    // Only allow POST requests
    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }

    try {
      const { image, mimeType, context, textOnly } = await request.json();

      // Handle text-only mode
      if (textOnly && context) {
        return await handleTextOnlyAnalysis(context, env);
      }

      if (!image) {
        return new Response(JSON.stringify({ error: 'No image provided' }), {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        });
      }

      // Build the user context section if provided
      const userContextSection = context 
        ? `\n\nUSER PROVIDED CONTEXT (use this to improve accuracy):\n"${context}"\nConsider this information when identifying the food, brand, portion size, or calculating nutrition.`
        : '';

      // Call Gemini API with Google Search grounding enabled
      const geminiResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${env.GEMINI_API_KEY}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  {
                    text: `You are a nutrition expert assistant with access to Google Search. Analyze this food image and provide accurate nutritional information.${userContextSection}

IMPORTANT: Use Google Search to look up the EXACT nutritional facts for this specific food product or dish. If you can identify a brand name, product packaging, or specific restaurant/chain food, search for the official nutritional information.

Steps:
1. First identify what food/product is in the image (brand, name, type)
2. Search Google for the official nutritional facts for this specific item
3. If it's a branded product (like Pringles, Oreos, McDonald's, etc.), find the exact nutrition label data
4. If it's a homemade dish, search for standard nutritional estimates
5. If the user specified a portion (e.g., "ate half", "2 servings"), adjust the nutrition values accordingly

Return ONLY a valid JSON object with this exact structure (no markdown, no code blocks, just raw JSON):
{
  "food_name": "Specific name of the food (include brand if applicable)",
  "calories": exact calories as integer (adjusted for portion if specified),
  "protein": protein in grams as number,
  "carbs": carbohydrates in grams as number,
  "fat": fat in grams as number,
  "serving_size": "the serving size these values are for (reflect actual portion eaten if specified)",
  "confidence": "high/medium/low",
  "source": "where you found this nutritional data (e.g., 'Official Pringles nutrition label', 'USDA database', etc.)",
  "notes": "any additional relevant info (fiber, sugar, sodium if notable)"
}

If you cannot identify food in the image, return:
{
  "error": "Could not identify food in image",
  "food_name": null,
  "calories": 0,
  "protein": 0,
  "carbs": 0,
  "fat": 0
}

Prioritize accuracy from official sources over estimates.`,
                  },
                  {
                    inline_data: {
                      mime_type: mimeType || 'image/jpeg',
                      data: image,
                    },
                  },
                ],
              },
            ],
            tools: [
              {
                google_search: {}
              }
            ],
            generationConfig: {
              thinkingConfig: {
                thinkingLevel: "high"
              },
              maxOutputTokens: 8192,
            },
          }),
        }
      );

      if (!geminiResponse.ok) {
        const errorText = await geminiResponse.text();
        console.error('Gemini API error:', errorText);
        return new Response(
          JSON.stringify({ error: 'Failed to analyze image', details: errorText }),
          {
            status: 500,
            headers: {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*',
            },
          }
        );
      }

      const geminiData = await geminiResponse.json();
      
      // Extract the text response
      let nutritionText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || '';
      
      // Clean up the response - remove markdown code blocks if present
      nutritionText = nutritionText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      
      // Try to parse as JSON
      let nutritionData;
      try {
        nutritionData = JSON.parse(nutritionText);
      } catch (e) {
        // If parsing fails, return raw text with error
        nutritionData = {
          error: 'Failed to parse nutrition data',
          raw_response: nutritionText,
          food_name: 'Unknown',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
        };
      }

      return new Response(JSON.stringify(nutritionData), {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    } catch (error) {
      console.error('Worker error:', error);
      return new Response(
        JSON.stringify({ error: 'Internal server error', message: error.message }),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }
  },
};

// Handle text-only food analysis (no image)
async function handleTextOnlyAnalysis(foodDescription, env) {
  try {
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: `You are a nutrition expert assistant with access to Google Search. The user wants nutritional information for the following food:

"${foodDescription}"

IMPORTANT: Use Google Search to look up the EXACT nutritional facts for this specific food product or dish. If it mentions a brand name, restaurant, or specific product, search for the official nutritional information.

Steps:
1. Identify the food item (brand, restaurant, dish name)
2. Search Google for the official nutritional facts
3. If it's a branded product or restaurant item, find the exact nutrition data
4. If it's a homemade dish, search for standard nutritional estimates
5. If the user specified a portion (e.g., "ate half", "2 servings"), adjust the nutrition values accordingly

Return ONLY a valid JSON object with this exact structure (no markdown, no code blocks, just raw JSON):
{
  "food_name": "Specific name of the food (include brand if applicable)",
  "calories": exact calories as integer (adjusted for portion if specified),
  "protein": protein in grams as number,
  "carbs": carbohydrates in grams as number,
  "fat": fat in grams as number,
  "serving_size": "the serving size these values are for (reflect actual portion eaten if specified)",
  "confidence": "high/medium/low",
  "source": "where you found this nutritional data (e.g., 'Official McDonald's nutrition info', 'USDA database', etc.)",
  "notes": "any additional relevant info (fiber, sugar, sodium if notable)"
}

If you cannot find nutritional information, return your best estimate with confidence: "low".

Prioritize accuracy from official sources over estimates.`,
                },
              ],
            },
          ],
          tools: [
            {
              google_search: {}
            }
          ],
          generationConfig: {
            thinkingConfig: {
              thinkingLevel: "high"
            },
            maxOutputTokens: 8192,
          },
        }),
      }
    );

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error('Gemini API error:', errorText);
      return new Response(
        JSON.stringify({ error: 'Failed to analyze food', details: errorText }),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }

    const geminiData = await geminiResponse.json();
    
    let nutritionText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || '';
    nutritionText = nutritionText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    
    let nutritionData;
    try {
      nutritionData = JSON.parse(nutritionText);
    } catch (e) {
      nutritionData = {
        error: 'Failed to parse nutrition data',
        raw_response: nutritionText,
        food_name: 'Unknown',
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
      };
    }

    return new Response(JSON.stringify(nutritionData), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  } catch (error) {
    console.error('Text analysis error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: error.message }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }
}
