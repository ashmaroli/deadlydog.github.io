---
title: Using MSBuild to publish a VS 2012 SSDT .sqlproj database project the same way as a VS 2010 .dbproj database project (using command line arguments to specify the database to publish to)
date: 2013-03-18T14:34:13-06:00
last_modified_at: 2019-03-22T00:00:00-00:00
permalink: /using-msbuild-to-publish-a-vs-2012-ssdt-sqlproj-database-project-the-same-way-as-a-vs-2010-dbproj-database-project/
categories:
  - Build
  - Database
  - MSBuild
  - SQL
  - Visual Studio
tags:
  - .sqlproj
  - argument
  - Build
  - command line
  - Database
  - DB
  - Deploy
  - MSBuild
  - parameter
  - Publish
  - SQL
  - SSDT
  - Visual Studio
---

We recently upgraded from VS (Visual Studio) 2010 to VS 2012, and with it had to upgrade our .dbproj database project to a .sqlproj. When making the switch I realized that .sqlproj database projects do not support specifying the database to deploy to as MSBuild command line arguments; instead you have to pass in the path to an xml file that has the necessary information.

So with the old .dbproj database project, you could deploy it to a database using:

```shell
MSBuild /t:Deploy /p:TargetDatabase="[DbName]";TargetConnectionString="Data Source=[Db.Server];Integrated Security=True;Pooling=False" /p:DeployToDatabase="True" "[PathToBranch]Database\Database.dbproj"
```

But with the new .sqlproj database project you have to do:

```shell
MSBuild /t:Publish /p:SqlPublishProfilePath="myPublishFile.publish.xml" "[PathToBranch]Database\Database.sqlproj"
```

Where "myPublishFile.publish.xml" contains the database server and name to publish to.

One other minor thing to note is that it is called "deploying" the database with .dbproj, and is called "publishing" the database with .sqlproj; so when I say Deploy or Publish, I mean the same thing.

We use TFS at my organization and while making new builds for our Test environment, we have the build process deploy the database solution to our various Test databases. This would mean that for us I would either need to:

1 - create a new [DbName].publish.xml file for each database, check it into source control, and update the build template to know about the new file, or

2 - update the file contents of our myPublishFile.publish.xml file dynamically during the build to replace the Database Name and Server in the file before publishing to the database (i.e. read in file contents, replace string, write file contents back to file, publish to DB, repeat).

Option 1 means more work every time I want to add a new Test database to publish to. Option 2 is better, but still means having to update my TF Build template and create a new activity to read/write the new contents to the file.

Instead, there is a 3rd option, which is to simply add the code below to the bottom of the .sqlproj file. This will add some new MSBuild targets to the .sqlproj that will allow us to specify the database name and connection string using similar MSBuild command line parameters that we used to deploy the .dbproj project.

The code presented here is [based on this post](http://huddledmasses.org/adventures-getting-msbuild-tfs-and-sql-server-data-tools-to-work-together/), but the author has closed the comments section on that post and has not replied to my emails about the bugs in his code and example, so I thought I would share my modified and enhanced solution.

```xml
  <!--
    Custom targets and properties added so that we can specify the database to publish to using command line parameters with VS 2012 .sqlproj projects, like we did with VS 2010 .dbproj projects.
    This allows us to specify the MSBuild command-line parameters TargetDatabaseName, and TargetConnectionString when Publishing, and PublishToDatabase when Building.
    I also stumbled across the undocumented parameter, PublishScriptFileName, which can be used to specify the generated sql script file name, just like DeployScriptFileName used to in VS 2010 .dbproj projects.
    Taken from: https://blog.danskingdom.com/using-msbuild-to-publish-a-vs-2012-ssdt-sqlproj-database-project-the-same-way-as-a-vs-2010-dbproj-database-project/
  -->
  <PropertyGroup Condition="'$(TargetDatabaseName)' != '' Or '$(TargetConnectionString)' != ''">
    <PublishToDatabase Condition="'$(PublishToDatabase)' == ''">False</PublishToDatabase>
    <TargetConnectionStringXml Condition="'$(TargetConnectionString)' != ''">
      <TargetConnectionString xdt:Transform="Replace">$(TargetConnectionString)</TargetConnectionString>
    </TargetConnectionStringXml>
    <TargetDatabaseXml Condition="'$(TargetDatabaseName)' != ''">
      <TargetDatabaseName xdt:Transform="Replace">$(TargetDatabaseName)</TargetDatabaseName>
    </TargetDatabaseXml>
    <TransformPublishXml>
        <Project xmlns:xdt="http://schemas.microsoft.com/XML-Document-Transform" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
        <PropertyGroup>$(TargetConnectionStringXml)$(TargetDatabaseXml)</PropertyGroup>
        </Project>
    </TransformPublishXml>
    <SqlPublishProfilePath Condition="'$([System.IO.Path]::IsPathRooted($(SqlPublishProfilePath)))' == 'False'">$(MSBuildProjectDirectory)\$(SqlPublishProfilePath)</SqlPublishProfilePath>
    <!-- In order to do a transform, we HAVE to change the SqlPublishProfilePath -->
    <TransformOutputFile>$(MSBuildProjectDirectory)\Transformed_$(TargetDatabaseName).publish.xml</TransformOutputFile>
    <TransformScope>$([System.IO.Path]::GetFullPath($(MSBuildProjectDirectory)))</TransformScope>
    <TransformStackTraceEnabled Condition="'$(TransformStackTraceEnabled)'==''">False</TransformStackTraceEnabled>
  </PropertyGroup>
  <Target Name="AfterBuild" Condition="'$(PublishToDatabase)'=='True'">
    <CallTarget Targets="Publish" />
  </Target>
  <UsingTask TaskName="ParameterizeTransformXml" AssemblyFile="$(MSBuildExtensionsPath)\Microsoft\VisualStudio\v$(VisualStudioVersion)\Web\Microsoft.Web.Publishing.Tasks.dll" />
  <Target Name="BeforePublish" Condition="'$(TargetDatabaseName)' != '' Or '$(TargetConnectionString)' != ''">
    <Message Text="TargetDatabaseName = '$(TargetDatabaseName)', TargetConnectionString = '$(TargetConnectionString)', PublishScriptFileName = '$(PublishScriptFileName)', Transformed Sql Publish Profile Path = '$(TransformOutputFile)'" Importance="high" />
    <!-- If TargetDatabaseName or TargetConnectionString, is passed in then we use the tokenize transform to create a parameterized sql publish file -->
    <Error Condition="!Exists($(SqlPublishProfilePath))" Text="The SqlPublishProfilePath '$(SqlPublishProfilePath)' does not exist, please specify a valid file using msbuild /p:SqlPublishProfilePath='Path'" />
    <ParameterizeTransformXml Source="$(SqlPublishProfilePath)" IsSourceAFile="True" Transform="$(TransformPublishXml)" IsTransformAFile="False" Destination="$(TransformOutputFile)" IsDestinationAFile="True" Scope="$(TransformScope)" StackTrace="$(TransformStackTraceEnabled)" SourceRootPath="$(MSBuildProjectDirectory)" />
    <PropertyGroup>
      <SqlPublishProfilePath>$(TransformOutputFile)</SqlPublishProfilePath>
    </PropertyGroup>
  </Target>
</pre>
</div>

<div id="scid:fb3a1972-4489-4e52-abe7-25a00bb07fdf:fd8b0e8d-f40e-4c6f-846e-511003fc9d0a" class="wlWriterEditableSmartContent" style="float: none; padding-bottom: 0px; padding-top: 0px; padding-left: 0px; margin: 0px; display: inline; padding-right: 0px">
  <p>
    <a href="/assets/Posts/2013/11/MsBuildTargetsToPublishSqlProjFromCommandLine.txt" target="_blank">Download the code to avoid website copy-paste formatting problems (right-click this, choose Save Link/Target As...)</a>
  </p>
</div>



So after adding this code at the bottom of the .sqlproj file (above the </Project> tag though), you can now build and publish the database solution from the MSBuild command line using:

<div id="scid:C89E2BDB-ADD3-4f7a-9810-1B7EACF446C1:3e2ed27f-66e6-4855-9afa-b7487eb386cc" class="wlWriterEditableSmartContent" style="float: none; padding-bottom: 0px; padding-top: 0px; padding-left: 0px; margin: 0px; display: inline; padding-right: 0px">
  <pre style=white-space:normal>

  <pre class="brush: bash; gutter: false; title: ; notranslate" title="">
MSBuild /t:Build /p:TargetDatabaseName="[DbName]";TargetConnectionString="Data Source=[Db.Server];Integrated Security=True;Pooling=False" /p:PublishToDatabase="True" /p:SqlPublishProfilePath="Template.publish.xml" "[PathToBranch]\Database\Database.sqlproj"
```

Here you can see the 3 new parameters that we’ve added being used: TargetDatabaseName, TargetConnectionString, and PublishToDatabase.

When the TargetDatabaseName or TargetConnectionString parameters are provided we generated a new transformed .publish.xml file, which is the same as the provided "Template.publish.xml" file, but with the database and connection string values replaced with the provided values.

The PublishToDatabase parameter allows us to publish to the database immediately after the project is built; without this you would have to first call MSBuild to Build the database project, and then call MSBuild again to Publish it (or perhaps using "/t:Build;Publish" would work, but I didn’t test that).

If you want to simply publish the database project without building first (generally not recommended), you can do:

```shell
MSBuild /t:Publish /p:TargetDatabaseName="[DbName]";TargetConnectionString="Data Source=[Db.Server];Integrated Security=True;Pooling=False" /p:SqlPublishProfilePath="Template.publish.xml" "[PathToBranch]\Database\Database.sqlproj"
```

Be careful though, since if you don’t do a Build first, any changes that have been made since the last time the .sqlproj file was built on your machine won’t be published to the database.

Notice that I still have to provide a path to the template publish.xml file to transform, and that the path to this file is relative to the .sqlproj file (in this example the Template.publish.xml and .sqlproj files are in the same directory). You can simply use one of the publish.xml files generated by Visual Studio, and then the TargetDatabaseName and TargetConnectionString xml element values will be replaced with those given in the command line parameters. This allows you to still define any other publish settings as usual in the xml file.

Also notice that the PublishToDatabase parameter is only used when doing a Build, not a Publish; providing it when doing a Publish will not hurt anything though.

While creating my solution, I also accidentally stumbled upon what seems to be an undocumented SSDT parameter, PublishScriptFileName. While the DeployScriptFileName parameter could be used in VS 2010 .dbproj projects to change the name of the generated .sql file, I noticed that changing its value in the .publish.xml file didn’t seem to have any affect at all (so I’m not really sure why Visual Studio puts it in there). I randomly decided to try passing in PublishScriptFileName from the command line, and blamo, it worked! I tried changing the <DeployScriptFileName> element in the .publish.xml file to <PublishScriptFileName>, but it still didn’t seem to have any effect.

So now if I wanted to deploy my database project to 3 separate databases, I could do so with the following code to first Build the project, and the Publish it to the 3 databases:

```shell
MSBuild /t:Build "[PathToBranch]\Database\Database.sqlproj"
MSBuild /t:Publish /p:TargetDatabaseName="[DbName1]";TargetConnectionString="Data Source=[Db.Server];Integrated Security=True;Pooling=False" /p:PublishScriptFileName="[DbName1].sql" /p:SqlPublishProfilePath="Template.publish.xml" "[PathToBranch]\Database\Database.sqlproj"
MSBuild /t:Publish /p:TargetDatabaseName="[DbName2]";TargetConnectionString="Data Source=[Db.Server];Integrated Security=True;Pooling=False" /p:PublishScriptFileName="[DbName2].sql" /p:SqlPublishProfilePath="Template.publish.xml" "[PathToBranch]\Database\Database.sqlproj"
MSBuild /t:Publish /p:TargetDatabaseName="[DbName3]";TargetConnectionString="Data Source=[Db.Server];Integrated Security=True;Pooling=False" /p:PublishScriptFileName="[DbName3].sql" /p:SqlPublishProfilePath="Template.publish.xml" "[PathToBranch]\Database\Database.sqlproj"
```

You could also instead just call MSBuild using the Build target with the PublishToDatabase parameter (which might actually be the safer bet); whatever you prefer. I have found that once the database project is built once, as long as no changes are made to it then subsequent "builds" of the project only take a second or two since it detects that no changes have been made and skips doing the build.

If you have any questions or feedback, let me know.

Happy coding!
