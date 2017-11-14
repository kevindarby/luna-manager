module Luna.Manager.Command.Options where

import Prologue

import Data.Text (Text)
import Options.Applicative as Opts
import Control.Monad.State.Layered

import qualified Luna.Manager.System.Info as Info


------------------------------
-- === Command options  === --
------------------------------

-- === Definition === --

data Options = Options
    { _globals :: GlobalOpts
    , _command :: Command
    } deriving (Show)

data GlobalOpts = GlobalOpts
    { _batchMode      :: Bool
    , _guiInstaller   :: Bool
    , _verbose        :: Bool
    } deriving (Show)

data Command = Install       InstallOpts
             | Update
             | SwitchVersion SwitchVersionOpts
             | Develop       DevelopOpts
             | MakePackage   MakePackageOpts
             | NextVersion   NextVersionOpts
             | Info
             deriving (Show)

data InstallOpts = InstallOpts
    { _selectedComponent        :: Maybe Text
    , _selectedVersion          :: Maybe Text
    , _selectedInstallationPath :: Maybe Text
    , _nightlyInstallation      :: Bool
    , _devInstallation          :: Bool
    } deriving (Show)

data MakePackageOpts = MakePackageOpts
    { _cfgPath :: Text
    } deriving (Show)

data SwitchVersionOpts = SwitchVersionOpts
    { _targetVersion :: Text
    } deriving (Show)

data DevelopOpts = DevelopOpts
    { _target               :: Text
    , _repositoryPath       :: Maybe Text
    , _downloadDependencies :: Bool
    } deriving (Show)

data NextVersionOpts = NextVersionOpts
    { _configFilePath :: Text
    , _nightly        :: Bool
    , _release        :: Bool
    } deriving (Show)

makeLenses ''GlobalOpts
makeLenses ''Options
makeLenses ''InstallOpts
makeLenses ''MakePackageOpts
makeLenses ''SwitchVersionOpts
makeLenses ''DevelopOpts
makeLenses ''NextVersionOpts

-- small helpers for Options
verboseOpt, guiInstallerOpt :: MonadGetter Options m => m Bool
verboseOpt      = view (globals . verbose)      <$> get @Options
guiInstallerOpt = view (globals . guiInstaller) <$> get @Options

-- === Instances === --

instance Default InstallOpts where def = InstallOpts def def def False False



------------------------------
-- === Argument parsing === --
------------------------------

-- === Parsers === --

evalOptionsParserT :: MonadIO m => StateT Options m a -> m a
evalOptionsParserT m = evalStateT m =<< parseOptions

parseOptions :: MonadIO m => m Options
parseOptions = liftIO $ customExecParser (prefs showHelpOnEmpty) optsParser where
    commands           = mconcat [cmdInstall, cmdMkpkg, cmdUpdate, cmdDevelop, cmdSwitchVersion, cmdNextVer, cmdInfo]
    optsParser         = info (helper <*> optsProgram) (fullDesc <> header ("Luna ecosystem manager (" <> Info.version <> ")") <> progDesc Info.synopsis)

    -- Commands
    cmdInstall         = Opts.command "install"        . info optsInstall       $ progDesc "Install components. By default displays only the release versions."
    cmdUpdate          = Opts.command "update"         . info (pure Update)     $ progDesc "Update components"
    cmdSwitchVersion   = Opts.command "switch-version" . info optsSwitchVersion $ progDesc "Switch installed component version"
    cmdDevelop         = Opts.command "develop"        . info optsDevelop       $ progDesc "Setup development environment"
    cmdMkpkg           = Opts.command "make-package"   . info optsMkpkg         $ progDesc "Prepare installation package"
    cmdNextVer         = Opts.command "next-version"   . info optsNextVersion   $ progDesc "Get a newer version of a package, by default incrementing the build number (x.y.z.w)"
    cmdInfo            = Opts.command "info"           . info (pure Info)       $ progDesc "Show environment information"

    -- Options
    optsProgram        = Options           <$> optsGlobal <*> hsubparser commands
    optsGlobal         = GlobalOpts        <$> Opts.switch (long "batch"   <> help "Do not run interactive mode")
                                           <*> Opts.switch (long "gui"     <> help "Used by the graphic installer to instruct the installer it's being run in a graphical mode")
                                           <*> Opts.switch (long "verbose" <> help "Print more output from the commands ran by the manager.")
    optsMkpkg          = MakePackage       <$> optsMkpkg'
    optsMkpkg'         = MakePackageOpts   <$> strArgument (metavar "CONFIG"  <> help "Config (luna-package.yaml) file path, usually found in the Luna Studio repo")
    optsSwitchVersion  = SwitchVersion     <$> optsSwitchVersion'
    optsSwitchVersion' = SwitchVersionOpts <$> strArgument (metavar "VERSION" <> help "Target version to switch to")
    optsDevelop        = Develop           <$> optsDevelop'
    optsDevelop'       = DevelopOpts       <$> (strArgument $ metavar "CONFIG" <> help "Config (luna-package.yaml) file path, usually found in the Luna Studio repo")
                                           <*> (optional . strOption $ long "path" <> metavar "PATH" <> help "Path under which the new repository will be created and set up.")
                                           <*> Opts.switch (long "download-dependencies" <> help "Instead of setting up the fresh repo, just download the external dependencies into the existing repo.")
    optsInstall        = Install           <$> optsInstall'
    optsInstall'       = InstallOpts       <$> (optional . strOption $ long "component" <> metavar "COMPONENT" <> help "Component to install")
                                           <*> (optional . strOption $ long "version"   <> metavar "VERSION"   <> help "Version to install")
                                           <*> (optional . strOption $ long "path"      <> metavar "PATH"      <> help "Installation path")
                                           <*> Opts.switch (long "nightly" <> help "Include nightly builds in the list of builds available for installation.")
                                           <*> Opts.switch (long "dev"     <> help "Include developer builds in the list of builds available for installation.")
    optsNextVersion    = NextVersion       <$> optsNextVersion'
    optsNextVersion'   = NextVersionOpts   <$> strArgument (metavar "CONFIG" <> help "Config (luna-package.yaml) file path, usually found in the Luna Studio repo")
                                           <*> Opts.switch (long "nightly"   <> help "Get a new nightly version number (x.y.z).")
                                           <*> Opts.switch (long "release"   <> help "Get a new release version number (x.y).")
