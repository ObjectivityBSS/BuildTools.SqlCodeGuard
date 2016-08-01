# BuildTools.SqlCodeGuard
## 1. What, where, why?
SQL Code Guard is a free solution that provides static analysis for T-Sql code.
This NuGet package is based on BuildTools.NET available at https://github.com/jonwagner/BuildTools.NET
and uses some of SQL Code Guard files (command line tool and settings editor) which are available at http://sqlcodeguard.com/.
## 2. How to use the package after adding to the project?
You can just add the package to the project, and don’t have to do anything. There is a default settings
file which says to check for all types of issues the tool can recognize. You can change the behaviour
by changing the setting file or additional MSBuild properties, which are described in next paragraph.
## 3. What properties can I set in the MSBuild project file?
### 3.1. SqlCodeGuardEnabled
Determines whether the tool is enabled. It’s set to ‘true’ for both configurations, Debug and Release, by default.
Sample usage:
```
<SqlCodeGuardEnabled>true</SqlCodeGuardEnabled>
```
### 3.2. SqlCodeGuardConfigFile
Locates the settings file. By default it points at file inside the NuGet package directory.
You can copy the file to your solution/project and point at it like in the following example.
Sample usage:
```
<SqlCodeGuardConfigFile>$(SolutionDir)Settings.SqlCodeGuard</SqlCodeGuardConfigFile>
```
### 3.3. SqlCodeGuardIncludeIssue and SqlCodeGuardExcludeIssue
Defines a list of code issues separated with semicolon which will be checked by the tool (SqlCodeGuardIncludeIssue)
and a list of code issues separated with semicolon which will not be checked by the tool (SqlCodeGuardExcludeIssue).
You can have for example a setting file shared by every project in the solution, and differences put in this property.
But you don’t have to use this property. You can have separate setting file for each project.
By default both properties are empty.
Sample usage:
```
<SqlCodeGuardIncludeIssue>DEP023;SC002</SqlCodeGuardIncludeIssue>
<SqlCodeGuardExcludeIssue>SC001</SqlCodeGuardExcludeIssue>
```
### 3.4. SqlCodeGuardTreatWarningsAsErrors
Determines whether by default all warnings should be reported as errors (1) or not (0).
You can override this behaviour with the next two properties.
By default the setting is enabled (1) for Release configuration and disabled (0) for Debug configuration.
Sample usage:
```
<SqlCodeGuardTreatWarningsAsErrors>0</SqlCodeGuardTreatWarningsAsErrors>
```
### 3.5. SqlCodeGuardTreatIssueAsWarning and SqlCodeGuardTreatIssueAsError
Defines a list of code issues separated with semicolon which will be reported as warnings or errors
regardless of the SqlCodeGuardTreatWarningsAsErrors property value.
If you provide the same issue code in both properties, it will be reported as an error.
By default both properties are empty.
Sample usage:
```
<SqlCodeGuardTreatIssueAsWarning>SC004</SqlCodeGuardTreatIssueAsWarning>
<SqlCodeGuardTreatIssueAsError>PE016</SqlCodeGuardTreatIssueAsError>
```
### 3.6 ExcludeFromSqlCodeGuard
In order to exclude code analysis on a particular file it is enough to insert ExcludeFromSqlCodeGuard under the source file reference.
This option is particularly nice if many files should be ignored during code analysis especially in legacy projects.
Sample usage:
```
<Compile Include="File.sql">
  <ExcludeFromSqlCodeGuard>true</ExcludeFromSqlCodeGuard>
</Compile>
```
## 4. The settings file.
There is a default settings file available in the NuGet package directory located at ‘build\Settings.SqlCodeGuard’.
You can copy it to the solution or project directory and then override the SqlCodeGuardConfigFile property,
so it points at the copied setting file. You can edit the setting file manually to quickly set the issue settings
to ‘Warning’ or ‘Ignore’, e.g. ‘<EI018>Warning</EI018>’ or ‘<EI019>Ignore</EI019>’.
Unfortunately, due to tool limitations, you cannot set any issue setting to ‘Error’ in this file,
and you have to use MSBuild properties for that.
You can check the list of issues and their explanation at http://sqlcodeguard.com/index-database-issues.html.
You can also use the simple settings editor which is located at ‘build\SqlCodeGuard.Cmd.exe’ to edit the setting file,
just run it from the command line and provide the path to the setting file as a first and only parameter.
