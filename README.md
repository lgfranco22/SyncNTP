# SyncNTP

Sincronizador de horário para Windows utilizando o protocolo SNTP (Simple Network Time Protocol), com seleção automática de servidor de fallback, ajuste direto do relógio do sistema e registro de eventos no Windows.

## Visão geral

O SyncNTP consulta um servidor NTP por UDP na porta 123, valida a resposta recebida e ajusta o relógio do Windows utilizando a API `SetSystemTime` do Win32.

O projeto foi desenvolvido para execução automatizada, principalmente por meio do Agendador de Tarefas do Windows, sem necessidade de manter uma janela de console aberta.

### Principais recursos

- Consulta de servidores NTP por IPv4.
- Configuração de servidor principal e servidor de fallback.
- Tentativa automática com o servidor secundário caso o principal falhe.
- Validação da versão, do modo, do estado de sincronização e do estrato da resposta NTP.
- Ajuste do relógio do Windows por meio da API Win32.
- Registro de sucessos e falhas no Visualizador de Eventos.
- Notificação por MessageBox em caso de erro, quando executado em uma sessão interativa.
- Compilação para executável `.exe` sem janela de console.
- Compatibilidade com execução automatizada pelo Agendador de Tarefas.

## Requisitos

- Windows com suporte à API Win32 utilizada pelo projeto.
- Windows PowerShell compatível com o script.
- Conexão de rede capaz de alcançar um servidor NTP via UDP na porta 123.
- Permissões administrativas ou privilégios suficientes para ajustar o relógio do sistema e registrar a fonte de eventos.
- PS2EXE para gerar o executável.

## Configuração dos servidores

Por padrão, o script utiliza:

| Função | Servidor |
|---|---|
| Principal | `200.160.7.197` |
| Fallback | `a.st1.ntp.br` |

Os servidores podem ser substituídos pelos argumentos fornecidos na execução.

O servidor de fallback só é consultado quando a tentativa com o servidor principal falha. Se os dois servidores falharem, o programa registra o erro e, quando possível, notifica o usuário.

## Compilação para EXE

Instale o módulo PS2EXE no PowerShell:

```powershell
Install-Module -Name ps2exe -Scope CurrentUser
```

Se a política de execução impedir o carregamento do módulo, você pode liberar temporariamente a execução na sessão atual:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

Carregue o módulo:

```powershell
Import-Module ps2exe
```

Gere o executável sem console:

```powershell
Invoke-PS2EXE -InputFile ".\syncntp.ps1" -OutputFile ".\syncntp.exe" -NoConsole -STA -NoOutput -NoError -Title "Sincronizador NTP" -Description "Sincronizacao do relogio do Windows" -Version "1.0.0.0"
```

O arquivo `syncntp.exe` será criado no caminho especificado em `-OutputFile`.

> **Observação:** o PS2EXE empacota o script PowerShell em um executável que depende do ambiente PowerShell do Windows. Isso não equivale à compilação para código nativo nem garante a ocultação do código-fonte.

## Utilização

### Executar com os servidores padrão

```cmd
syncntp.exe
```

### Informar servidor principal e fallback

Ao executar o EXE gerado pelo PS2EXE, utilize `-end` para encaminhar os argumentos ao script:

```cmd
syncntp.exe -end "200.160.7.197" "a.st1.ntp.br"
```

O primeiro argumento representa o servidor principal; o segundo representa o servidor de fallback.

Também é possível executar o script diretamente:

```powershell
.\syncntp.ps1 "200.160.7.197" "a.st1.ntp.br"
```

## Agendador de Tarefas do Windows

Para executar o sincronizador automaticamente:

1. Abra o Agendador de Tarefas.
2. Crie uma tarefa, em vez de uma tarefa básica, para ter acesso às opções avançadas.
3. Configure o gatilho desejado, como na inicialização do sistema ou em um horário recorrente.
4. Na guia **Geral**, habilite **Executar com privilégios mais altos** e selecione a conta apropriada.
5. Na guia **Ações**, configure o executável e os argumentos.

Exemplo:

**Programa/script**

```text
C:\SyncNTP\syncntp.exe
```

**Adicionar argumentos**

```text
-end "200.160.7.197" "a.st1.ntp.br"
```

Uma tarefa executada sem uma sessão interativa não consegue exibir normalmente uma MessageBox na área de trabalho do usuário. Nessa situação, os eventos do Windows são o principal meio de consultar o resultado da execução.

### Importar tarefa do Agendador de Tarefas

O projeto disponibiliza o arquivo `SyncNTP.xml` com uma configuração predefinida para o Agendador de Tarefas do Windows.

Para importar a tarefa:

1. Baixe o arquivo `SyncNTP.xml` do repositório.
2. Confirme que o executável `syncntp.exe` está no caminho definido no XML. Caso necessário, ajuste o caminho e os argumentos da ação.
3. Pressione `Win + R`, digite `taskschd.msc` e pressione Enter.
4. No painel **Ações**, clique em **Importar Tarefa...**.
5. Selecione o arquivo `SyncNTP.xml` e confirme a importação.
6. Na guia **Geral**, confira a conta utilizada e habilite **Executar com privilégios mais altos**, caso necessário.
7. Na guia **Disparadores**, confira quando a tarefa será executada.
8. Na guia **Ações**, confirme o caminho do executável e os argumentos.
9. Clique em **OK** para salvar a tarefa. Caso solicitado, forneça as credenciais necessárias.
10. Selecione a tarefa importada e clique em **Executar** para testar a configuração.

**Importante:** revise as configurações da tarefa antes de executá-la. O caminho do executável, os argumentos, a conta de execução e os privilégios podem precisar ser adaptados ao computador. Uma tarefa importada não é necessariamente executada imediatamente.

## Visualizador de Eventos

Os eventos são gravados no log **Aplicativo** do Windows utilizando a fonte `SyncNTP`.

Para consultar os registros:

1. Execute `eventvwr.msc`.
2. Abra **Logs do Windows → Aplicativo**.
3. Localize eventos cuja fonte seja `SyncNTP`.

### Identificadores de evento

| ID | Tipo | Descrição |
|---:|---|---|
| `1000` | Informação | Sincronização concluída. |
| `2000` | Erro | Falha na sincronização. |
| `2001` | Erro | O relógio foi ajustado, mas não foi possível registrar o evento de sucesso. |

A criação inicial da fonte de eventos exige permissões adequadas. Recomenda-se executar a configuração inicial e a tarefa com os privilégios necessários.

## Como funciona

O processo de sincronização segue estas etapas:

1. Resolve o endereço IPv4 do servidor selecionado.
2. Envia uma solicitação SNTP de 48 bytes por UDP.
3. Aguarda a resposta do servidor, com tempo limite de recebimento.
4. Valida campos importantes da resposta NTP.
5. Extrai o timestamp de transmissão do servidor e converte-o para UTC.
6. Ajusta o relógio do Windows com `SetSystemTime`.
7. Registra o resultado no log Aplicativo do Windows.

A consulta utiliza o timestamp de transmissão do servidor. O script não implementa um algoritmo completo de disciplina de relógio nem compensa explicitamente o tempo de ida e volta da rede. Portanto, a precisão efetiva depende do servidor, da rede e do atraso da comunicação.

## Solução de problemas

### Nenhum servidor NTP respondeu

Verifique:

- A conectividade com o servidor.
- A resolução DNS, quando for utilizado um nome de domínio.
- A disponibilidade do servidor NTP.
- A saída e o retorno de tráfego UDP na porta 123.
- As regras de firewall locais ou da rede.

### Falha ao ajustar o relógio

Confirme se o processo possui os privilégios necessários para alterar o horário do sistema. No Agendador de Tarefas, verifique a conta utilizada e a opção **Executar com privilégios mais altos**.

### Não aparecem eventos no Visualizador de Eventos

Verifique se a fonte `SyncNTP` foi criada e se a conta utilizada tem permissões para registrar eventos no log Aplicativo.

### A MessageBox não aparece

A notificação visual só pode ser exibida em uma sessão interativa. Para tarefas executadas sem o usuário conectado, consulte o Visualizador de Eventos.

## Segurança e limitações

- O protocolo NTP não autentica criptograficamente o servidor neste projeto.
- Um servidor malicioso ou comprometido pode fornecer um horário incorreto.
- A alteração do relógio afeta o sistema inteiro e pode influenciar logs, certificados, autenticação e tarefas agendadas.
- A disponibilidade da sincronização depende da conectividade com pelo menos um servidor válido.
- A fonte de eventos e o ajuste do relógio exigem permissões adequadas.
- O projeto não substitui todos os recursos do serviço Windows Time (`W32Time`), como a disciplina contínua do relógio e os mecanismos nativos de seleção de fonte.

Para ambientes nos quais a segurança, a rastreabilidade ou a precisão rigorosa sejam essenciais, avalie servidores NTP confiáveis e mecanismos de autenticação apropriados.
