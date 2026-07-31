# ADR-003 — Confiança, projeções e risco

- Status: aceito
- Data: 22/07/2026

## Contexto

Projeções e níveis de risco precisavam ser reproduzíveis e explicáveis.

## Decisão

Rendas usam pesos centralizados: confirmada 100%, alta 80%, média 50% e baixa 20%. Cancelada ou atrasada sem nova previsão vale zero.

O sistema apresenta projeção nominal e conservadora. Risco segue condições determinísticas de crítico, risco, atenção e saudável; prevalece o nível mais grave e os fatos causadores são exibidos.

## Consequências

- Gemini não classifica risco nem calcula projeção.
- Pesos e limiares ficam em configuração versionada.
- Testes cobrem cada condição e combinações.
