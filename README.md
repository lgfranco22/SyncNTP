# SyncNTP

Sincronizador de horário para Windows utilizando o protocolo SNTP (Simple Network Time Protocol), com seleção automática de servidor de fallback, ajuste direto do relógio do sistema e registro de eventos no Windows.

## Visão geral

O SyncNTP consulta servidores NTP por UDP na porta 123, valida a resposta recebida e ajusta o relógio do Windows utilizando a API `SetSystemTime` do Win32.

O projeto foi desenvolvido para execução automatizada por meio do Agendador de Tarefas do Windows. O executável disponibilizado no Release 1.4 foi compilado sem janela de console, permitindo a execução em segundo plano.

## Principais recursos

- Consulta de servidores NTP por IPv4.
- Configuração de servidor principal e servidor de fallback.
- Tentativa automática com o servidor secundário quando o principal falha.
- Validação da versão, do modo, do estado de sincronização e do estrato da resposta NTP.
- Ajuste do relógio do Windows por meio da API Win32.
- Registro de sucessos e falhas no Visualizador de Eventos.
- Notificação por MessageBox em caso de erro, quando executado em uma sessão interativa.
- Executável sem janela de console.
- Execução automatizada pelo Agendador de Tarefas do Windows.

## Download

O executável pré-compilado está disponível no **Release 1.4**, na seção *Releases* deste repositório.

Baixe o arquivo `syncntp.exe` diretamente do Release 1.4. O código-fonte `syncntp.ps1` e o modelo de tarefa `SyncNTP.xml` estão disponíveis no repositório.

Para utilizar a configuração de tarefa fornecida, siga as instruções da seção [Importar tarefa do Agendador de Tarefas](#importar-tarefa-do-agendador-de-tarefas).

## Requisitos

- Windows com suporte à API Win32 utilizada pelo projeto.
- Conexão de rede capaz de alcançar um servidor NTP via UDP na porta 123.
- Permissões suficientes para ajustar o relógio do sistema e registrar eventos no log Aplicativo do Windows.
- Para compilar o executável a partir do código-fonte, Windows PowerShell e o módulo PS2EXE.

## Configuração dos servidores

Por padrão, o projeto utiliza os seguintes servidores:

| Função | Servidor |
|---|---|
| Principal | `200.160.7.197` |
| Fallback | `a.st1.ntp.br` |

Os servidores podem ser substituídos pelos argumentos fornecidos na execução.

O servidor de fallback só é consultado quando a tentativa com o servidor principal falha. Se ambos falharem, o programa registra o erro e, quando existe uma sessão interativa disponível, exibe uma notificação ao usuário.

## Instalação

### 1. Baixar o executável

Acesse a seção *Releases* deste repositório e baixe o arquivo `syncntp.exe` disponível no Release 1.4.

### 2. Definir o local de instalação

O arquivo `SyncNTP.xml` fornecido no repositório utiliza o seguinte caminho para o executável:

```text
C:\Program Files\SyncNTP\syncntp.exe
```

Crie a pasta `C:\Program Files\SyncNTP` e coloque o executável nela. A criação da pasta e a gravação de arquivos nesse local podem exigir privilégios administrativos.

Caso escolha outro diretório, altere os campos `Command` e `WorkingDirectory` da tarefa para corresponder ao local escolhido.

### 3. Importar a tarefa

Siga as instruções da seção [Importar tarefa do Agendador de Tarefas](#importar-tarefa-do-agendador-de-tarefas).

### 4. Testar a execução

Após importar a tarefa, selecione-a no Agendador de Tarefas e clique em **Executar**. Em seguida, consulte o Visualizador de Eventos para verificar se a sincronização foi concluída.

## Utilização

### Executar com os servidores padrão

Ao executar o script diretamente, os servidores definidos como padrão serão utilizados:

```powershell
.\syncntp.ps1
```

O executável compilado também utiliza esses servidores quando não recebe argumentos.

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

O projeto inclui o arquivo `SyncNTP.xml`, que contém uma configuração predefinida para executar o sincronizador automaticamente.

A tarefa está configurada para iniciar:

- Um minuto após a inicialização do Windows.
- Um minuto após o logon do usuário.
- Um minuto após o desbloqueio da sessão.
- Diariamente, por volta das 12h, com atraso aleatório de até um minuto.

A tarefa também permite execução sob demanda, aceita execução na bateria e está configurada para ignorar novas instâncias quando já existe uma execução em andamento.

### Importar tarefa do Agendador de Tarefas

Antes de importar, coloque `syncntp.exe` no caminho especificado no XML ou prepare-se para alterar o caminho da ação após a importação.

**1. Preparar o SID da conta**

O arquivo `SyncNTP.xml` utiliza um marcador de exemplo no campo `UserId`:

```xml
<UserId>REPLACE_WITH_YOUR_USER_SID</UserId>
```

Esse marcador deve ser substituído pelo SID da conta do Windows que executará a tarefa.

Para consultar o SID da conta atual, abra o CMD e execute:

```cmd
whoami /user
```

Copie o SID exibido e substitua o marcador no XML por esse valor. Salve o arquivo antes de continuar.

**2. Importar o arquivo XML**

1. Pressione `Win + R`.
2. Digite `taskschd.msc` e pressione Enter.
3. No painel **Ações**, clique em **Importar Tarefa...**.
4. Selecione o arquivo `SyncNTP.xml` disponível no repositório.
5. Confirme a importação e, se solicitado, ajuste a conta utilizada pela tarefa.

**3. Conferir as configurações**

Após a importação, abra as propriedades da tarefa e verifique:

- **Geral:** confira a conta de execução e a opção **Executar com privilégios mais altos**.
- **Disparadores:** confira os gatilhos de inicialização, logon, desbloqueio e execução diária.
- **Ações:** confirme o caminho do executável e os argumentos.

A ação fornecida utiliza:

**Programa/script**

```text
C:\Program Files\SyncNTP\syncntp.exe
```

**Adicionar argumentos**

```text
-end "200.160.7.197" "a.st1.ntp.br"
```

**4. Salvar e testar**

Clique em **OK** para salvar a tarefa. Caso solicitado, forneça as credenciais necessárias.

Selecione a tarefa e clique em **Executar** para testar a configuração.

**Importante:** a tarefa utiliza `InteractiveToken`, portanto depende de uma sessão interativa do usuário configurado. A MessageBox de erro não será exibida normalmente quando a tarefa executar em uma sessão não interativa, como quando o usuário estiver desconectado. Nessa situação, consulte o Visualizador de Eventos.

## Compilação a partir do código-fonte

Se preferir gerar o executável a partir do script PowerShell, instale o módulo PS2EXE:

```powershell
Install-Module -Name ps2exe -Scope CurrentUser
```

Caso a política de execução impeça temporariamente o carregamento do módulo, libere a execução na sessão atual:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

Carregue o módulo:

```powershell
Import-Module ps2exe
```

Gere o executável sem janela de console:

```powershell
Invoke-PS2EXE -InputFile ".\syncntp.ps1" -OutputFile ".\syncntp.exe" -NoConsole -STA -NoOutput -NoError -Title "Sincronizador NTP" -Description "Sincronizacao do relogio do Windows" -Version "1.4.0.0"
```

O arquivo `syncntp.exe` será criado no caminho definido em `-OutputFile`.

> **Observação:** o PS2EXE empacota o script PowerShell em um executável que depende do ambiente PowerShell do Windows. Isso não equivale à compilação para código nativo nem garante a ocultação do código-fonte.

## Visualizador de Eventos

Os eventos são gravados no log **Aplicativo** do Windows utilizando a fonte `SyncNTP`.

Para consultar os registros:

1. Execute `eventvwr.msc`.
2. Abra **Logs do Windows → Aplicativo**.
3. Localize os eventos cuja fonte seja `SyncNTP`.

### Identificadores de evento

| ID | Tipo | Descrição |
|---:|---|---|
| `1000` | Informação | Sincronização concluída. |
| `2000` | Erro | Falha na sincronização. |
| `2001` | Erro | O relógio foi ajustado, mas não foi possível registrar o evento de sucesso. |

A criação inicial da fonte de eventos exige permissões adequadas. Caso os eventos não apareçam, verifique as permissões da conta utilizada e se a fonte `SyncNTP` foi criada corretamente.

## Como funciona

O processo de sincronização segue estas etapas:

1. Resolve o endereço IPv4 do servidor selecionado.
2. Envia uma solicitação SNTP de 48 bytes por UDP.
3. Aguarda uma resposta do servidor, com tempo limite de recebimento.
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

### A tarefa não é importada

Confirme se substituiu `REPLACE_WITH_YOUR_USER_SID` pelo SID válido da conta escolhida. Verifique também se o XML está salvo em uma codificação compatível com a declaração do arquivo.

## Segurança e limitações

- O protocolo NTP não autentica criptograficamente o servidor neste projeto.
- Um servidor malicioso ou comprometido pode fornecer um horário incorreto.
- A alteração do relógio afeta o sistema inteiro e pode influenciar logs, certificados, autenticação e tarefas agendadas.
- A disponibilidade da sincronização depende da conectividade com pelo menos um servidor válido.
- A fonte de eventos e o ajuste do relógio exigem permissões adequadas.
- O projeto não substitui todos os recursos do serviço Windows Time (`W32Time`), como a disciplina contínua do relógio e os mecanismos nativos de seleção de fonte.

Para ambientes nos quais a segurança, a rastreabilidade ou a precisão rigorosa sejam essenciais, avalie servidores NTP confiáveis e mecanismos de autenticação apropriados.
