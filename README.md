Banco relacional do Projeto Interdisciplinar

## 1. Descrição

Este repositório contém o script, que implementa um banco de dados PostgreSQL normalizado. Este banco é projetado para gerenciar usuários e administradores, focado em rastreamento de atividades.

## 2. Como Usar

### Pré-requisitos
* Um servidor PostgreSQL em execução.

### Instalação
1.  Crie um novo banco de dados (ex: `meu_projeto_db`).
2.  Execute o script completo neste banco de dados.

O script é **idempotente**, o que significa que ele pode ser executado várias vezes sem causar erros. A seção `R E S E T` no início do script garante que todas as estruturas antigas (tabelas, funções, views) sejam derrubadas com `CASCADE` antes de serem recriadas.

## 3. Estrutura do Banco (Esquema)

### Tabelas Principais
* `usuario`: Armazena os dados dos usuários da plataforma.
* `admin`: Armazena os dados dos administradores do sistema.
* `log_rpa`: Tabela para registro de logs de processos de Automação (RPA).

### Tabelas de Auditoria e Logs
* `log_admin`: Registra todas as alterações (`INSERT`, `UPDATE`, `DELETE`) na tabela `admin`. Usa `JSONB` para dados antigos/novos.
* `log_usuario`: Registra todas as alterações na tabela `usuario`.
* `acesso_diario`: Registra o primeiro acesso de cada usuário por dia (DAU).

**Nota de Arquitetura:** As tabelas de log (`log_admin`, `log_usuario`, `acesso_diario`) usam `ON DELETE SET NULL`. Isso garante que, se um usuário ou admin for removido, seu histórico de auditoria e acesso seja **preservado**

## 4.Principais Funções e Views

### Autenticação
* `func_autenticar_e_registrar_acesso(p_Email VARCHAR, p_Senha VARCHAR)`
    * **O que faz:** Função central de login. Verifica as credenciais do usuário e, se estiverem corretas, registra o acesso diário (DAU) na tabela `acesso_diario`.
    * **Retorna:** `INTEGER` (o `nCdUsuario`) em caso de sucesso, ou `NULL` em caso de falha.

### CRUD (Exemplos)
* `proc_adicionar_usuario(...)`
* `proc_adicionar_admin(...)`
* `proc_remover_usuario(Email VARCHAR)`
* `proc_remover_admin(Email VARCHAR)`

### Views (Relatórios)
* `view_stats_rpa`
    * **O que faz:** Agrupa as estatísticas de log do RPA por status (`INFO`, `ERROR`, etc.), mostrando contagens e datas.
* `view_idade`
    * **O que faz:** Calcula a idade (em anos) de todos os administradores cadastrados.

## 6. Autor

* **Kear_07** por Nutria
