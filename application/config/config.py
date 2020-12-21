class Config(object):
    DEBUG = False
    TESTING = False
    DB_SERVER = 'xxx.xxx.xxx.xxx'
    DB_USER = 'user'

    @property
    def SQLALCHEMY_DATABASE_URI(self):
        return f'mysql://{self.DB_USER}@{self.DB_SERVER}/you-todoo'


class ProductionConfig(Config):
    DB_SERVER = 'localhost'


class DevelopmentConfig(Config):
    DB_SERVER = 'localhost'
    DEBUG = True


class TestingConfig(Config):
    DB_SERVER = 'localhost'
    DEBUG = True
    DATABASE_URI = 'sqlite:///test.db'
    # DATABASE_URI = 'sqlite:///:memory:'
