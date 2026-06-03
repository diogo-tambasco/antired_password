---
name: antired
description: Preenche o .env do projeto atual puxando os segredos do cofre antired_password. Use quando o usuário digitar /antired <projeto> ou pedir pra buscar/preencher as senhas ou o .env de um projeto a partir do cofre.
---

# antired — puxar segredos pro .env

Preenche o `.env` do diretório atual com os segredos de um projeto guardados no cofre
**antired_password**, via um token de acesso revogável (sem master password).

## Passos

1. **Descubra o projeto.** O usuário normalmente passa o nome: `/antired acta` → projeto `acta`.
   Se ele não passou, rode `antired ls` pra listar os projetos disponíveis e pergunte qual.

2. **Garanta o CLI.** Use o script `antired` que acompanha esta skill (no mesmo diretório:
   `./antired`) ou instalado no PATH. Na primeira vez, se não houver config, o CLI pede
   `antired login <url> <token>` — peça ao usuário a URL do cofre e um token (gerado em
   `<url>/access_tokens`).

3. **Puxe o .env.** No diretório do projeto do usuário:
   ```bash
   antired env <projeto>
   ```
   Escreve `./.env` (modo 0600; faz backup do `.env` anterior em `.env.bak`).
   Para só inspecionar sem gravar: `antired env <projeto> -`.

4. **Confirme** quantas variáveis foram escritas (o CLI imprime a contagem).

## Regras de segurança (importante)
- **Nunca** ecoe no chat o conteúdo do `.env`, os valores dos segredos, nem o token.
  Se precisar referenciar, use só os **nomes** das chaves.
- Recuse URLs `http://` que não sejam localhost (o CLI já bloqueia).
- O `.env` é sempre gravado com permissão 0600.

## Abrir no navegador
`antired open` abre o cofre no browser (gerenciar segredos/tokens).
